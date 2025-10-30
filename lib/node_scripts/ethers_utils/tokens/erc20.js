const { ethers, Contract } = require('ethers');
const { loadAbi, callContractMethod, initializeWallet } = require('../utils/helpers');
const CHAIN_ID = 8453;
const { MaxUint256 } = ethers;

// --- ERC20 token functions ---
// getTokenBalance
async function getTokenBalance(walletAddress, tokenAddress, providerUrl) {
    const abiPath = path.join(__dirname, '../contracts', 'erc20.json');
    const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
    
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const tokenContract = new Contract(tokenAddress, abi, provider);

    try {
        const tokenBalance = await tokenContract.balanceOf(walletAddress);
        const decimals = await tokenContract.decimals();
        return ethers.formatUnits(tokenBalance, decimals);
    } catch (error) {
        console.error(`Error fetching token balance: ${error.message}`);
        throw error;
    }
}

// getTokenDetails
async function getTokenDetails(tokenAddress, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const erc20Abi = loadAbi('erc20.json');
    const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, provider);

    try {
        const name = await tokenContract.name();
        const symbol = await tokenContract.symbol();
        const decimals = await tokenContract.decimals();

        return {
            name,
            symbol,
            decimals: decimals.toString()
        };
    } catch (error) {
        console.error("Error fetching token details:", error);
        return null;
    }
}

// sendErc20
async function sendErc20(
  privateKey,
  tokenAddress,
  toAddress,
  amount,
  decimals,
  providerUrl,
  nonce,
  maxFeePerGasString,
  maxPriorityFeePerGasString
) {
  try {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const wallet   = new ethers.Wallet(privateKey, provider);
    const erc20Abi = loadAbi('erc20.json');
    const token    = new Contract(tokenAddress, erc20Abi, wallet);

    // format amount like your other functions
    const formattedAmount = parseFloat(amount).toFixed(Number(decimals));
    const amountWei       = ethers.parseUnits(formattedAmount, Number(decimals));

    // parse gas overrides
    const maxFeePerGas         = BigInt(maxFeePerGasString);
    const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);

    // perform the transfer (no wait)
    const result = await callContractMethod(
      token,
      'transfer',
      [toAddress, amountWei],
      maxFeePerGas,
      maxPriorityFeePerGas,
      nonce,
      { shouldWait: false }
    );

    if (result.hash) {
      return { success: true, txHash: result.hash, nonce };
    } else {
      return { success: false, error: result.error, nonce };
    }
  } catch (error) {
    console.error(`Error sending ERC-20: ${error.message}`);
    return { success: false, error, nonce };
  }
}

// infiniteApprove
async function infiniteApprove(privateKey, tokenAddress, providerUrl, nonce, maxFeePerGasString, maxPriorityFeePerGasString, spenderAddress) {
    const erc20Abi = loadAbi('erc20.json');

    const maxFeePerGas         = BigInt(maxFeePerGasString);
    const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);

    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);    
    const wallet = new ethers.Wallet(privateKey, provider);

    const tokenContract = new Contract(tokenAddress, erc20Abi, wallet);

    const approvalResponse = await callContractMethod(
        tokenContract,
        'approve',
        [ spenderAddress, MaxUint256 ],
        maxFeePerGas,
        maxPriorityFeePerGas,
        nonce,
        { shouldWait: false }
    );

    if (approvalResponse.hash) {
        return { success: true, txHash: approvalResponse.hash, nonce: nonce };
    } else {
        return { success: false, error: approvalResponse.error, nonce: nonce };
    }
}

// isInfiniteApproval
async function isInfiniteApproval(privateKey, tokenAddress, spenderAddress, providerUrl) {
    const erc20Abi = loadAbi('erc20.json');

    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const { wallet, walletAddress } = initializeWallet(provider, privateKey);
    const tokenContract = new Contract(tokenAddress, erc20Abi, wallet);

    const allowance = await tokenContract.allowance(walletAddress, spenderAddress);

    return allowance === MaxUint256;
}

module.exports = {
  getTokenBalance,
  getTokenDetails,
  sendErc20,
  infiniteApprove,
  isInfiniteApproval
};