const { ethers, Contract } = require('ethers');
const { loadAbi, callContractMethod, initializeWallet, sortTokens } = require('../utils/helpers');
const CHAIN_ID = 8453;

// --- Uniswap V3 functions ---
// getQuote
/*
The Uniswap quoter functions are declared as nonpayable rather than view—even 
though they don’t modify state. This is an implementation choice by Uniswap. 
As a result, if you call them normally, the node will expect a state-changing 
call and will attempt to send a transaction (which costs gas), even if nothing 
is actually being changed.

Using the static method tells ethers.js to simulate the call locally without 
creating a transaction. It forces a read-only execution using the current state, 
which is why it doesn’t cost any gas.
*/
async function getQuote(tokenIn, tokenOut, feeTier, amountIn, tokenInDecimals, tokenOutDecimals, providerUrl) {
    const quoterAbi = loadAbi('quoter.json');
    const quoterAddress = '0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a'; // Base
    
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const quoterContract = new ethers.Contract(quoterAddress, quoterAbi, provider);
    
    // Convert to wei
    const formattedAmount = parseFloat(amountIn).toFixed(Number(tokenInDecimals));
    const amountInWei = ethers.parseUnits(formattedAmount, Number(tokenInDecimals));

    const params = {
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        amountIn: amountInWei,
        fee: feeTier,
        sqrtPriceLimitX96: 0n
      };

  try {
    const result = await quoterContract.quoteExactInputSingle.staticCall(params);
    const amountOut = Array.isArray(result) ? result[0] : result;

    return amountOut;
  } catch (error) {
    console.error(`Error in getQuote: ${error.message}`);
    throw error;
  }
}

// quoteMeetsMinimum
async function quoteMeetsMinimum(tokenIn, tokenOut, feeTier, amountIn, tokenInDecimals, tokenOutDecimals, minAmountOut, providerUrl) {
    try {  
        const formattedMinOut = parseFloat(minAmountOut).toFixed(Number(tokenOutDecimals));
        const minAmountOutRaw = ethers.parseUnits(formattedMinOut, Number(tokenOutDecimals));

        const quoteRaw = await getQuote(tokenIn, tokenOut, feeTier, amountIn, tokenInDecimals, tokenOutDecimals, providerUrl);
        const valid = BigInt(quoteRaw) >= BigInt(minAmountOutRaw)
        return {
            success: true,
            valid,                                 
            quoteRaw: ethers.formatUnits(quoteRaw, Number(tokenOutDecimals)),
            minAmountOutRaw: ethers.formatUnits(minAmountOutRaw, Number(tokenOutDecimals))
          };
    } catch (e) {
        return { success: false, error: e };
    }
}

// swap
async function swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOut, providerUrl, nonce, maxFeePerGas, maxPriorityFeePerGas) {
    //const erc20Abi = loadAbi('erc20.json');
    const swapRouterAbi = loadAbi('swaprouter.json');

    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const { wallet, walletAddress } = initializeWallet(provider, privateKey);

    const swapRouterAddress = '0x2626664c2603336E57B271c5C0b26F421741e481'; // Base
    const swapRouterContract = new Contract(swapRouterAddress, swapRouterAbi, wallet);

    // Convert amount to trade into wei
    const formattedAmount = parseFloat(amountIn).toFixed(Number(tokenInDecimals));
    const amountInWei = ethers.parseUnits(formattedAmount, Number(tokenInDecimals));

    const swapDeadline = Math.floor(Date.now() / 1000 + 60 * 60);
    const swapTxInputs = {
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: feeTier,
        recipient: walletAddress,
        deadline: BigInt(swapDeadline),
        amountIn: amountInWei,
        amountOutMinimum: minAmountOut,
        sqrtPriceLimitX96: 0n
    };

    const swapTxResponse = await callContractMethod(
        swapRouterContract,
        'exactInputSingle',
        [swapTxInputs],
        maxFeePerGas,
        maxPriorityFeePerGas,
        nonce,
        { shouldWait: false }
    );

    if (swapTxResponse.hash) {
        return { success: true, txHash: swapTxResponse.hash };
    } else {
        // Catch STF errors
        return {
            success: false,
            error: swapTxResponse.error
        };
    }
}

// buyWithMinAmount
async function buyWithMinAmount(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, tokenOutDecimals, feeTier, minAmountOut, providerUrl, nonce, maxFeePerGasString, maxPriorityFeePerGasString) {
    // Convert minAmountOut
    const formattedMinOut = parseFloat(minAmountOut).toFixed(Number(tokenOutDecimals));
    const minAmountOutRaw = ethers.parseUnits(formattedMinOut, Number(tokenOutDecimals));
    const maxFeePerGas         = BigInt(maxFeePerGasString);
    const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);
  
    const result = await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOutRaw, providerUrl, nonce, maxFeePerGas, maxPriorityFeePerGas);

    let txHash;

    if (result.success) {
        txHash = result.txHash;
    } else if (result.error?.transaction) {
        // on underpriced or other broadcast error, derive from the raw tx
        txHash = ethers.keccak256(result.error.transaction);
    }

    const bumpNonce = Boolean(
        result.success ||         // we saw swapTxResponse.hash
        result.error?.transaction // or we got a raw signed tx in the catch
    );

    return {
        success: result.success,
        error:   result.error,
        txHash,
        nonce,
        bumpNonce
    };
}

// sellWithMinAmount
async function sellWithMinAmount(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, tokenOutDecimals, feeTier, minAmountOut, providerUrl, nonce, maxFeePerGasString, maxPriorityFeePerGasString) {
    // Convert minAmountOut
    const formattedMinOut = parseFloat(minAmountOut).toFixed(Number(tokenOutDecimals));
    const minAmountOutRaw = ethers.parseUnits(formattedMinOut, Number(tokenOutDecimals));
    const maxFeePerGas         = BigInt(maxFeePerGasString);
    const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);

    const result = await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOutRaw, providerUrl, nonce, maxFeePerGas, maxPriorityFeePerGas);

    let txHash;

    if (result.success) {
        txHash = result.txHash;
    } else if (result.error?.transaction) {
        // on underpriced or other broadcast error, derive from the raw tx
        txHash = ethers.keccak256(result.error.transaction);
    }

    const bumpNonce = Boolean(
        result.success ||         // we saw swapTxResponse.hash
        result.error?.transaction // or we got a raw signed tx in the catch
    );

    return {
        success: result.success,
        error:   result.error,
        txHash,
        nonce,
        bumpNonce
    };
}

// findMostLiquidPool
async function findMostLiquidPool(tokenA, tokenB, providerUrl) {
    const uniswapV3FactoryAbi = loadAbi('uniswapv3factory.json');
    const uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');
  
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
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
      //await new Promise(resolve => setTimeout(resolve, 200)); // 200ms delay
    }
  
    if (!bestPoolAddress) {
      throw new Error('Pool does not exist for the given token pair in any fee tier.');
    }
  
    // Return the best pool address and its fee tier.
    return { poolAddress: bestPoolAddress, feeTier: bestFeeTier };
}

// getPriceFromPool
async function getPriceFromPool(tokenA, tokenADecimals, tokenB, tokenBDecimals, poolAddress, providerUrl) {
    const uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  
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
    //const rawPrice = (1.0001 ** Number(tick)) / (10 ** (token0Decimals - token1Decimals));
    const rawPrice = (1.0001 ** Number(tick)) / (10 ** (token1Decimals - token0Decimals));

    let price;
    if (tokenA.toLowerCase() === sortedToken0.toLowerCase()) {
      price = rawPrice;
    } else {
      price = 1 / rawPrice;
    }

    const formattedPrice = price.toFixed(tokenBDecimals); // tokenB is the quote token
  
    return formattedPrice;
}

// getTokenPrice
async function getTokenPrice(tokenA, tokenADecimals, tokenB, tokenBDecimals, providerUrl) {
    const { poolAddress, feeTier } = await findMostLiquidPool(tokenA, tokenB, providerUrl);
    const price = await getPriceFromPool(tokenA, tokenADecimals, tokenB, tokenBDecimals, poolAddress, providerUrl);
    return { poolAddress: poolAddress, feeTier: feeTier, price: price };
}

module.exports = {
  getQuote,
  quoteMeetsMinimum,
  swap,
  buyWithMinAmount,
  sellWithMinAmount,
  findMostLiquidPool,
  getPriceFromPool,
  getTokenPrice
};