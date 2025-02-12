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

async function getTokenDetails(tokenAddress, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl);
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

async function sell(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, providerUrl) {
    return await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, providerUrl);
}

function sortTokens(tokenA, tokenB) {
    return tokenA.toLowerCase() < tokenB.toLowerCase()
      ? [tokenA, tokenB]
      : [tokenB, tokenA];
}

async function getTokenPrice(tokenA, tokenADecimals, tokenB, tokenBDecimals, providerUrl) {
    const { poolAddress, feeTier } = await findMostLiquidPool(tokenA, tokenB, providerUrl);
    const price = await getPriceFromPool(tokenA, tokenADecimals, tokenB, tokenBDecimals, poolAddress, providerUrl);
    return { poolAddress: poolAddress, feeTier: feeTier, price: price };
}

async function findMostLiquidPool(tokenA, tokenB, providerUrl) {
    const uniswapV3FactoryAbi = loadAbi('uniswapv3factory.json');
    const uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');
  
    const provider = new ethers.JsonRpcProvider(providerUrl);
    const uniswapV3FactoryAddress = '0x33128a8fC17869897dcE68Ed026d694621f6FDfD';
    const factoryContract = new ethers.Contract(uniswapV3FactoryAddress, uniswapV3FactoryAbi, provider);
  
    const [token0, token1] = sortTokens(tokenA, tokenB);
  
    // Define the fee tiers for Uniswap V3.
    const feeTiers = [500, 3000, 10000];
    let bestPoolAddress = null;
    let bestFeeTier = null;
    let bestLiquidity = null;
  
    // Iterate through each fee tier and find the pool with the highest liquidity.
    for (const fee of feeTiers) {
      const currentPoolAddress = await factoryContract.getPool(token0, token1, fee);
      if (currentPoolAddress && currentPoolAddress !== ethers.ZeroAddress) {
        const poolContract = new ethers.Contract(currentPoolAddress, uniswapV3PoolAbi, provider);
        // Get the liquidity from the pool.
        const liquidityRaw = await poolContract.liquidity();
        // Convert the returned value to a BigInt for comparison.
        const currentLiquidity = ethers.toBigInt(liquidityRaw);
        
        if (!bestLiquidity || currentLiquidity > bestLiquidity) {
          bestLiquidity = currentLiquidity;
          bestPoolAddress = currentPoolAddress;
          bestFeeTier = fee;
        }
      }
    }
  
    if (!bestPoolAddress) {
      throw new Error('Pool does not exist for the given token pair in any fee tier.');
    }
  
    // Return the best pool address and its fee tier.
    return { poolAddress: bestPoolAddress, feeTier: bestFeeTier };
}

async function getPriceFromPool(tokenA, tokenADecimals, tokenB, tokenBDecimals, poolAddress, providerUrl) {
    const uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');
    const provider = new ethers.JsonRpcProvider(providerUrl);
  
    // To correctly compute the price, we need to know which token is token0.
    // We sort the token addresses, and then we assign decimals accordingly.
    const [sortedToken0, sortedToken1] = sortTokens(tokenA, tokenB);
    let token0Decimals, token1Decimals;
    if (tokenA.toLowerCase() === sortedToken0.toLowerCase()) {
      token0Decimals = tokenADecimals;
      token1Decimals = tokenBDecimals;
    } else {
      token0Decimals = tokenBDecimals;
      token1Decimals = tokenADecimals;
    }
  
    // Create a contract instance for the pool.
    const poolContract = new ethers.Contract(poolAddress, uniswapV3PoolAbi, provider);
    const slot0 = await poolContract.slot0();
    const { tick } = slot0;
  
    // Calculate the price.
    // The formula here uses the tick to derive the raw price, then inverts it.
    const rawPrice = (1.0001 ** Number(tick)) / (10 ** (token0Decimals - token1Decimals));

    let price;
    if (tokenA.toLowerCase() === sortedToken0.toLowerCase()) {
      price = rawPrice;
    } else {
      price = 1 / rawPrice;
    }

    const formattedPrice = price.toFixed(tokenBDecimals); // tokenB is the quote token
  
    return formattedPrice;
}

async function getTransactionReceipt(txHash, decimals, providerUrl) {
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

        let amountIn = "0";
        let amountOut = "0";

        if (receipt.logs.length > 0) {
            const decodedLogs = receipt.logs.map(log => {
                try {
                    return ethers.formatUnits(log.data, Number(decimals));
                } catch (error) {
                    return null;
                }
            }).filter(entry => entry !== null);

            if (decodedLogs.length > 0) {
                // The first log typically contains `amountOut`
                amountOut = decodedLogs[0]; 

                // The second log (if available) should contain `amountIn`
                if (decodedLogs.length > 1) {
                    amountIn = decodedLogs[1]; 
                }
            }
        }

        return {
            amountIn,
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
    getTokenDetails,
    swap,
    buy,
    sell,
    getTokenPrice,
    findMostLiquidPool,
    getPriceFromPool,
    getTransactionReceipt
};
