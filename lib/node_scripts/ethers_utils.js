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

async function calculateGasPrice(provider) {
    const feeData = await provider.getFeeData();
    const providerGasPrice = feeData.gasPrice ?? BigInt(0);
    return (providerGasPrice * 12n) / 10n; // Increase by 20%
}


function loadAbi(fileName) {
    const abiPath = path.join(__dirname, '../contracts', fileName);
    return JSON.parse(fs.readFileSync(abiPath, 'utf8'));
}

function initializeWallet(provider, privateKey) {
    const wallet = new ethers.Wallet(privateKey, provider);
    return { wallet, walletAddress: wallet.address };
}

async function swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, providerUrl) {
    const erc20Abi = loadAbi('erc20.json');
    const swapRouterAbi = loadAbi('swaprouter.json');

    const provider = new ethers.JsonRpcProvider(providerUrl);
    const { wallet, walletAddress } = initializeWallet(provider, privateKey);

    const swapRouterAddress = '0x2626664c2603336E57B271c5C0b26F421741e481'; // Base
    const swapRouterContract = new Contract(swapRouterAddress, swapRouterAbi, wallet);
    const tokenInContract = new Contract(tokenIn, erc20Abi, wallet);

    // Convert amount to trade into wei
    const amountInWei = ethers.parseUnits(amountIn.toString(), Number(tokenInDecimals));

    const gasPrice = await calculateGasPrice(provider);

    const allowance = await tokenInContract.allowance(walletAddress, swapRouterAddress);
    if (allowance < amountInWei) {
        await callContractMethod(tokenInContract, 'approve', [swapRouterAddress, amountInWei], gasPrice);
    }

    const swapDeadline = Math.floor(Date.now() / 1000 + 60 * 60);
    const swapTxInputs = {
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: 3000,
        recipient: walletAddress,
        deadline: BigInt(swapDeadline),
        amountIn: amountInWei,
        amountOutMinimum: 0n,
        sqrtPriceLimitX96: 0n
    };

    const swapTxResponse = await callContractMethod(
        swapRouterContract,
        'exactInputSingle',
        [swapTxInputs],
        gasPrice
    );

    return swapTxResponse.hash;
}

async function buy(privateKey, amountIn, tokenOut, tokenIn, tokenInDecimals, providerUrl) {
    return await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, providerUrl);
}

async function getTokenPrice(token0, token0Decimals, token1, token1Decimals, providerUrl) {
    uniswapV3FactoryAbi = loadAbi('uniswapv3factory.json');
    uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');

    const provider = new ethers.JsonRpcProvider(providerUrl);
    const uniswapV3FactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD';
    const factoryContract = new ethers.Contract(uniswapV3FactoryAddress, uniswapV3FactoryAbi, provider);

    try {
        const poolAddress = await factoryContract.getPool(token0, token1, 3000);
        if (!poolAddress || poolAddress === ethers.ZeroAddress) {
            throw new Error('Pool does not exist for the given token pair and fee.');
        }

        const poolContract = new ethers.Contract(poolAddress, uniswapV3PoolAbi, provider);
        const slot0 = await poolContract.slot0();
        const { tick } = slot0;

        const price = (1.0001 ** Number(tick)) / (10 ** (token0Decimals - token1Decimals));

        return 1 / price;
    } catch (error) {
        console.error(`Error fetching Uniswap price: ${error.message}`);
        throw error;
    }
}

async function getTransactionReceipt(txHash, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl);

    try {
        const receipt = await provider.getTransactionReceipt(txHash);
        if (!receipt) {
            console.error("Transaction receipt not found.");
            return null;
        }

        // Extract key fields
        const status = receipt.status; // 1 = success, 0 = failure
        const blockNumber = receipt.blockNumber;
        const gasUsed = receipt.gasUsed.toString(); // Convert BigInt to string

        // Extract amountOut from logs
        let amountOut = "0";
        if (receipt.logs.length > 0) {
            const decodedLogs = receipt.logs.map(log => {
                try {
                    return ethers.formatUnits(log.data, 18); // Assuming base token has 18 decimals
                } catch (error) {
                    return null;
                }
            }).filter(entry => entry !== null);

            if (decodedLogs.length > 0) {
                amountOut = decodedLogs[0]; // Use first decoded log
            }
        }

        return {
            amountOut,
            status,
            blockNumber,
            gasUsed
        };
    } catch (error) {
        console.error("Error fetching transaction receipt:", error.message);
        return null;
    }
}

module.exports = {
    getBalance,
    getTransactionCount,
    getTokenBalance,
    swap,
    buy,
    getTokenPrice,
    getTransactionReceipt
};
