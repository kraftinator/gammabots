const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');
const CHAIN_ID = 8453;

// --- Shared Helpers ---

function loadAbi(fileName) {
    const abiPath = path.join(__dirname, '../../../contracts', fileName);
    return JSON.parse(fs.readFileSync(abiPath, 'utf8'));
}

function initializeWallet(provider, privateKey) {
    const wallet = new ethers.Wallet(privateKey, provider);
    return { wallet, walletAddress: wallet.address };
}

async function callContractMethod(contract, methodName, args, maxFeePerGas, maxPriorityFeePerGas, nonce, { shouldWait = true } = {}) {
    try {
        const tx = await contract[methodName](...args, { maxFeePerGas, maxPriorityFeePerGas, nonce });
        if (shouldWait) {
            await tx.wait();
        }
        return tx;
    } catch (error) {
        console.error(`Error calling ${methodName}:`, error.message);
        return {
            success: false,
            error: {
                message: error.message,
                reason: error.reason || 'Unknown reason',
                code: error.code || 'UNKNOWN_ERROR',
                data: error.data || null,
                transaction: error.transaction || null
            }
        };
    }
}

function sortTokens(tokenA, tokenB) {
    return tokenA.toLowerCase() < tokenB.toLowerCase()
      ? [tokenA, tokenB]
      : [tokenB, tokenA];
}

module.exports = {
  loadAbi,
  initializeWallet,
  callContractMethod,
  sortTokens
};