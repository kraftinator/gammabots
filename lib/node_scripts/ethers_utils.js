const fs = require('fs');
const path = require('path');
const { ethers, Contract } = require('ethers');

async function getBalance(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl);
    const balance = await provider.getBalance(address);
    return ethers.formatEther(balance);
}

async function getTransactionCount(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl);
    const transactionCount = await provider.getTransactionCount(address);
    return transactionCount;
}

async function getTokenBalance(walletAddress, tokenAddress, providerUrl) {
    const abiPath = path.join(__dirname, '../contracts', 'erc20.json');
    const abi = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
    
    const provider = new ethers.JsonRpcProvider(providerUrl);
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

async function callContractMethod(contract, methodName, args, gasPrice) {
    try {
        const tx = await contract[methodName](...args, { gasPrice });
        await tx.wait();
        return tx;
    } catch (error) {
        console.error(`Error calling ${methodName}:`, error.message);
        throw error;
    }
}

async function swap(privateKey, amountIn, tokenIn, tokenOut, providerUrl) {
    const erc20AbiPath = path.join(__dirname, '../contracts', 'erc20.json');
    const erc20Abi = JSON.parse(fs.readFileSync(erc20AbiPath, 'utf8'));

    const swapRouterAbiPath = path.join(__dirname, '../contracts', 'swaprouter.json');
    const swapRouterAbi = JSON.parse(fs.readFileSync(swapRouterAbiPath, 'utf8'));

    const provider = new ethers.JsonRpcProvider(providerUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const walletAddress = wallet.address;
    
    const feeData = await provider.getFeeData();
    const providerGasPrice = feeData.gasPrice ?? BigInt(0);
    const gasPrice = (providerGasPrice * 12n) / 10n; // Increase price by 20%
    
    const swapRouterAddress = '0x2626664c2603336E57B271c5C0b26F421741e481'; // Base
    const swapRouterContract = new Contract(swapRouterAddress, swapRouterAbi, wallet);

    const tokenInContract = new Contract(tokenIn, erc20Abi, wallet);
    const tokenInBalance = await tokenInContract.balanceOf(walletAddress);

    const allowance = await tokenInContract.allowance(walletAddress, swapRouterAddress);

    if (allowance < tokenInBalance) {
        await callContractMethod(tokenInContract, 'approve', [swapRouterAddress, tokenInBalance], gasPrice);
    }

    const swapDeadline = Math.floor(Date.now() / 1000 + 60 * 60);
    const swapTxInputs = {
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: 3000,
        recipient: walletAddress,
        deadline: BigInt(swapDeadline),
        amountIn: amountIn,
        amountOutMinimum: 0n, // Minimum acceptable amount of tokenOut
        sqrtPriceLimitX96: 0n
    };

    const swapTxResponse = await callContractMethod(
        swapRouterContract,
        'exactInputSingle',
        [swapTxInputs], // Pass as an array with one tuple
        gasPrice
    );
    
    return swapTxResponse;
}

module.exports = {
    getBalance,
    getTransactionCount,
    getTokenBalance,
    swap
};
