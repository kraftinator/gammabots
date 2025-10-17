const { ethers, Contract } = require('ethers');
const { loadAbi, initializeWallet } = require('../utils/helpers');
const CHAIN_ID = 8453;

// --- WETH-specific functions ---
// wrapETH
async function wrapETH(
  privateKey, 
  providerUrl, 
  ethAmountToConvert, 
  ethReservePercentage = 1,
  nonce,
  maxFeePerGasString,
  maxPriorityFeePerGasString
) {
  const WETH_ADDRESS = '0x4200000000000000000000000000000000000006'; // WETH on Base
  const WETH_ABI = loadAbi('weth.json');

  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  const { wallet, walletAddress } = initializeWallet(provider, privateKey);

  const ethBalance = await provider.getBalance(walletAddress);
  if (ethBalance <= 0n) {
    return { success: false, error: { message: "No ETH balance to convert", code: "INSUFFICIENT_BALANCE" } };
  }

  const amountToConvertWei = ethers.parseEther(ethAmountToConvert.toString());
  if (amountToConvertWei > ethBalance) {
    return { success: false, error: { message: "Requested conversion exceeds balance", code: "INSUFFICIENT_BALANCE" } };
  }

  const ethToReserve = (amountToConvertWei * BigInt(ethReservePercentage)) / BigInt(100);
  const ethToConvert = amountToConvertWei - ethToReserve;

  if (ethToConvert <= 0n) {
    return { success: false, error: { message: "Amount too low after gas reserve", code: "INSUFFICIENT_AMOUNT_AFTER_RESERVE" } };
  }

  const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, wallet);
  const maxFeePerGas         = BigInt(maxFeePerGasString);
  const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);

  try {
    const tx = await wethContract.deposit({
      nonce,
      value: ethToConvert,
      maxFeePerGas,
      maxPriorityFeePerGas
    });

    return {
      success: true,
      txHash: tx.hash,
      nonce,
      amountConverted: ethers.formatEther(ethToConvert),
      ethReserved: ethers.formatEther(ethToReserve),
      bumpNonce: true   // tell Ruby to increment Redis
    };
  } catch (error) {
    console.error("Error converting ETH to WETH:", error.message);

    let txHash;
    if (error.transaction) {
      txHash = ethers.keccak256(error.transaction);
    }

    return {
      success: false,
      error: {
        message: error.message,
        reason: error.reason || 'Unknown reason',
        code: error.code || 'UNKNOWN_ERROR'
      },
      txHash,
      nonce,
      bumpNonce: Boolean(txHash)
    };
  }
}

// unwrapWETH
async function unwrapWETH(
  privateKey,
  providerUrl,
  wethAmountToUnwrap,
  nonce,
  maxFeePerGasString,
  maxPriorityFeePerGasString
) {
  const WETH_ADDRESS = '0x4200000000000000000000000000000000000006'; // WETH on Base
  const WETH_ABI = loadAbi('weth.json'); // must include withdraw(uint256)

  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  const { wallet, walletAddress } = initializeWallet(provider, privateKey);
  const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, wallet);

  // Convert input amount to wei (18 decimals fixed)
  const amountWei = ethers.parseEther(wethAmountToUnwrap.toString());

  // Check WETH balance first
  const wethBalance = await wethContract.balanceOf(walletAddress);
  if (amountWei > wethBalance) {
    return {
      success: false,
      error: {
        message: "Requested unwrap amount exceeds WETH balance",
        code: "INSUFFICIENT_BALANCE",
        available: ethers.formatEther(wethBalance),
        requested: wethAmountToUnwrap.toString()
      }
    };
  }

  // Parse gas overrides
  const maxFeePerGas         = BigInt(maxFeePerGasString);
  const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);

  try {
    // Broadcast tx but don't wait
    const tx = await wethContract.withdraw(amountWei, {
      nonce,
      maxFeePerGas,
      maxPriorityFeePerGas
    });

    return {
      success: true,
      txHash: tx.hash,
      nonce,
      amountUnwrapped: ethers.formatEther(amountWei),
      bumpNonce: true   // <-- tell Ruby side to increment Redis
    };
  } catch (error) {
    console.error("Error unwrapping WETH:", error.message);

    // If ethers.js gives us the raw tx, we can derive its hash anyway
    let txHash;
    if (error.transaction) {
      txHash = ethers.keccak256(error.transaction);
    }

    const bumpNonce = Boolean(txHash);

    return {
      success: false,
      error: {
        message: error.message,
        reason: error.reason || 'Unknown reason',
        code: error.code || 'UNKNOWN_ERROR'
      },
      txHash,
      nonce,
      bumpNonce
    };
  }
}

module.exports = {
  wrapETH,
  unwrapWETH
};