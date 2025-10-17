const { ethers, Contract } = require('ethers');
const { loadAbi } = require('../utils/helpers');
const CHAIN_ID = 8453;

// --- Receipt / analytics functions ---
// getNetSwapAmounts
async function getNetSwapAmounts(
  txHash,
  poolAddress,
  walletAddress,
  tokenAAddress,
  tokenADecimals,
  tokenBAddress,
  tokenBDecimals,
  providerUrl
) {
  // 0) Figure out which of your two tokens is token0 vs token1
  let token0Address, token1Address, token0Decimals, token1Decimals;
  if (tokenAAddress.toLowerCase() < tokenBAddress.toLowerCase()) {
    token0Address  = tokenAAddress;
    token0Decimals = Number(tokenADecimals);
    token1Address  = tokenBAddress;
    token1Decimals = Number(tokenBDecimals);
  } else {
    token0Address  = tokenBAddress;
    token0Decimals = Number(tokenBDecimals);
    token1Address  = tokenAAddress;
    token1Decimals = Number(tokenADecimals);
  }

  // 1) Fetch the receipt
  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  const receipt  = await provider.getTransactionReceipt(txHash);
  if (!receipt) return null;

  // 2) Pull only ERC-20 Transfer logs
  const transferTopic = ethers.id("Transfer(address,address,uint256)");
  const transferLogs  = receipt.logs.filter(log => log.topics[0] === transferTopic);

  // 3) Precompute padded topics for pool→wallet filtering
  //const poolTopic   = ethers.hexlify(ethers.zeroPadValue(ethers.toBytes(poolAddress), 32));
  const poolTopic = ethers.zeroPadValue(poolAddress, 32);
  //const walletTopic = ethers.hexlify(ethers.zeroPadValue(ethers.toBytes(walletAddress), 32));
  const walletTopic  = ethers.zeroPadValue(walletAddress, 32);

  // 4) Tally up sent/received for both tokens
  let t0Received = 0n, t0Sent = 0n;
  let t1Received = 0n, t1Sent = 0n;
  for (const log of transferLogs) {
    const addr      = log.address.toLowerCase();
    const fromTopic = log.topics[1];
    const toTopic   = log.topics[2];
    const val       = BigInt(log.data);

    if (addr === token0Address.toLowerCase()) {
      if (fromTopic === poolTopic   && toTopic === walletTopic) t0Received += val;
      if (fromTopic === walletTopic && toTopic === poolTopic)   t0Sent     += val;
    } else if (addr === token1Address.toLowerCase()) {
      if (fromTopic === poolTopic   && toTopic === walletTopic) t1Received += val;
      if (fromTopic === walletTopic && toTopic === poolTopic)   t1Sent     += val;
    }
  }

  // 5) Decide amountIn vs amountOut
  let amountIn, amountOut;
  if (t0Received > 0n) {
    // You bought token0 (so you spent token1)
    amountIn  = ethers.formatUnits(t1Sent, token1Decimals);
    amountOut = ethers.formatUnits(t0Received, token0Decimals);
  } else {
    // You sold token0 (so you received token1)
    amountIn  = ethers.formatUnits(t0Sent, token0Decimals);
    amountOut = ethers.formatUnits(t1Received, token1Decimals);
  }

  return {
    amountIn,
    amountOut,
    status:      receipt.status,
    blockNumber: receipt.blockNumber,
    gasUsed:     receipt.gasUsed.toString(),
  };
}


// getWrapReceipt
async function getWrapReceipt(txHash, providerUrl) {
  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  const receipt = await provider.getTransactionReceipt(txHash);
  if (!receipt) return null;

  return {
    status: receipt.status,
    blockNumber: receipt.blockNumber,
    gasUsed: receipt.gasUsed.toString(),
    effectiveGasPrice: receipt.effectiveGasPrice?.toString(),
  };
}

// getFee
async function getFee(txHash, providerUrl) {
  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  const receipt = await provider.send("eth_getTransactionReceipt", [txHash]);
  if (!receipt) return null;

  const gasUsed = BigInt(receipt.gasUsed);
  const effectiveGasPrice = BigInt(receipt.effectiveGasPrice || "0x0");
  const l1Fee = receipt.l1Fee ? BigInt(receipt.l1Fee) : 0n;

  const totalFeeWei = gasUsed * effectiveGasPrice + l1Fee;

  return ethers.formatEther(totalFeeWei);
}

// getEthTransferDetails
async function getEthTransferDetails(txHash, providerUrl) {
  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID)

  const tx = await provider.getTransaction(txHash)
  if (!tx) return null

  const receipt = await provider.getTransactionReceipt(txHash)
  const valueWei = tx.value ?? 0n

  return {
    fromAddress: tx.from,
    toAddress: tx.to,
    amountEth: ethers.formatEther(valueWei),
    amountWei: valueWei.toString(),
    status: receipt ? receipt.status : null,              // 1 = success, 0 = revert, null = not mined
    blockNumber: receipt ? Number(receipt.blockNumber) : null,
    txHash
  }
}

// getSwaps
async function getSwaps(walletAddress, lastProcessedBlock, currentBlock, providerUrl) {
    const fromBlock = Number(lastProcessedBlock) + 1;
    const toBlock = Number(currentBlock);
    
    if (fromBlock > toBlock) {
        return { transfers: [] };
    }
   
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID, { batchMaxCount: 1 })
    try {
        const assetTransfers = await provider.send("alchemy_getAssetTransfers", [{
            fromBlock: "0x" + fromBlock.toString(16),
            toBlock: "0x" + toBlock.toString(16),
            fromAddress: walletAddress,
            category: ["erc20"],
            withMetadata: true,
            excludeZeroValue: false
        }]);

        return assetTransfers.transfers || [];
    } catch (error) {
        return { success: false, error};
    }
}

// getStrategyNftDetails
async function getStrategyNftDetails(txHash, providerUrl) {
  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  const receipt  = await provider.getTransactionReceipt(txHash);
  if (!receipt) return null;

  // Use ERC721 ABI (with Transfer + tokenURI + ownerOf)
  const strategyNftAbi = loadAbi('strategynft.json');
  const iface = new ethers.Interface(strategyNftAbi);

  // ERC721 Transfer event
  const transferTopic = iface.getEvent("Transfer").topicHash;
  const log = receipt.logs.find(l => l.topics[0] === transferTopic);
  if (!log) {
    return {
      txHash,
      status: receipt.status,
      blockNumber: receipt.blockNumber,
      error: 'No Transfer event found'
    };
  }

  // Decode the Transfer event
  const decoded = iface.parseLog(log);
  const contractAddress = log.address;
  const tokenId = decoded.args.tokenId.toString();

  // Query the contract for ownerOf + tokenURI
  const contract = new ethers.Contract(contractAddress, strategyNftAbi, provider);
  const owner = await contract.ownerOf(tokenId);
  //const tokenURI = await contract.tokenURI(tokenId);
  const strategyJson = await contract.getStrategy(tokenId);

  return {
    txHash,
    status: receipt.status,
    blockNumber: receipt.blockNumber,
    contractAddress,
    tokenId,
    owner,
    //tokenURI // base64 encoded json
    strategyJson
  };
}

module.exports = {
  getNetSwapAmounts,
  getWrapReceipt,
  getFee,
  getEthTransferDetails,
  getSwaps,
  getStrategyNftDetails
};