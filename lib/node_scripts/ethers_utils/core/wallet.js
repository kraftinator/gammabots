const { ethers } = require('ethers');
const CHAIN_ID = 8453;

// --- Wallet & Account functions ---
// getBalance
async function getBalance(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const balance = await provider.getBalance(address);
    return ethers.formatEther(balance);
}

// getTransactionCount
async function getTransactionCount(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const transactionCount = await provider.getTransactionCount(address);
    return transactionCount;
}

// getPendingNonce
async function getPendingNonce(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const transactionCount = await provider.getTransactionCount(address, "pending");
    return transactionCount;
}

// getWalletAddress
function getWalletAddress(privateKey, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const wallet = new ethers.Wallet(privateKey, provider);
    return wallet.address;
}

// generateWallet
function generateWallet() {
    const randomWallet = ethers.Wallet.createRandom();
    
    return {
        address: randomWallet.address,
        privateKey: randomWallet.privateKey
    };
}

// sendEth
async function sendEth(
  privateKey,
  toAddress,
  amountEth,
  providerUrl,
  nonce,
  maxFeePerGasString,
  maxPriorityFeePerGasString
) {
  try {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const wallet   = new ethers.Wallet(privateKey, provider);

    const amountWei = ethers.parseEther(amountEth.toString());

    const maxFeePerGas         = BigInt(maxFeePerGasString);
    const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);

    const tx = await wallet.sendTransaction({
      to: toAddress,
      value: amountWei,
      nonce,
      maxFeePerGas,
      maxPriorityFeePerGas
    });

    return { success: true, txHash: tx.hash, nonce };
  } catch (error) {
    console.error(`Error sending ETH: ${error.message}`);
    return { success: false, error, nonce };
  }
}

module.exports = {
  getBalance,
  getTransactionCount,
  getPendingNonce,
  getWalletAddress,
  generateWallet,
  sendEth
};