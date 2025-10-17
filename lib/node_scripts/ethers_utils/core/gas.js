const { ethers } = require('ethers');
const CHAIN_ID = 8453;

// --- Gas-related functions ---
// calculateGasPrice
async function calculateGasPrice(provider) {
    const feeData = await provider.getFeeData();
    const providerGasPrice = feeData.gasPrice ?? BigInt(0);
    return (providerGasPrice * 12n) / 10n; // Increase by 20%
}

// getGasPrice
async function getGasPrice(providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const gasPrice = await calculateGasPrice(provider);
    return Number(gasPrice);
}

// getGasFees
async function getGasFees(providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const feeData = await provider.getFeeData();
    const baseTip = feeData.maxPriorityFeePerGas  ?? 0n;
    const baseCap = feeData.maxFeePerGas          ?? 0n;
    return {
        maxPriorityFeePerGas: baseTip.toString(),
        maxFeePerGas:         ((baseCap * 12n) / 10n).toString()
    };
}

module.exports = {
  calculateGasPrice,
  getGasPrice,
  getGasFees
};