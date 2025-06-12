const fs = require('fs');
const path = require('path');
const { ethers, Contract } = require('ethers');
const { MaxUint256 } = ethers;

const CHAIN_ID = 8453;

async function getBalance(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const balance = await provider.getBalance(address);
    return ethers.formatEther(balance);
}

async function getTransactionCount(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const transactionCount = await provider.getTransactionCount(address);
    return transactionCount;
}

async function getPendingNonce(address, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const transactionCount = await provider.getTransactionCount(address, "pending");
    return transactionCount;
}

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

async function calculateGasPrice(provider) {
    const feeData = await provider.getFeeData();
    const providerGasPrice = feeData.gasPrice ?? BigInt(0);
    return (providerGasPrice * 12n) / 10n; // Increase by 20%
}

async function getGasPrice(providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const gasPrice = await calculateGasPrice(provider);
    return Number(gasPrice);
}

function loadAbi(fileName) {
    const abiPath = path.join(__dirname, '../contracts', fileName);
    return JSON.parse(fs.readFileSync(abiPath, 'utf8'));
}

function initializeWallet(provider, privateKey) {
    const wallet = new ethers.Wallet(privateKey, provider);
    return { wallet, walletAddress: wallet.address };
}

function getWalletAddress(privateKey, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const wallet = new ethers.Wallet(privateKey, provider);
    return wallet.address;
}

function generateWallet() {
    const randomWallet = ethers.Wallet.createRandom();
    
    return {
        address: randomWallet.address,
        privateKey: randomWallet.privateKey
    };
}

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

async function getQuoteFormatted(tokenIn, tokenOut, feeTier, amountIn, tokenInDecimals, tokenOutDecimals, providerUrl) {
    const rawQuote = await getQuote(tokenIn, tokenOut, feeTier, amountIn, tokenInDecimals, tokenOutDecimals, providerUrl);
    return ethers.formatUnits(rawQuote, Number(tokenOutDecimals));
}

async function infiniteApprove(privateKey, tokenAddress, providerUrl, nonce, maxFeePerGasString, maxPriorityFeePerGasString) {
    const erc20Abi = loadAbi('erc20.json');

    const maxFeePerGas         = BigInt(maxFeePerGasString);
    const maxPriorityFeePerGas = BigInt(maxPriorityFeePerGasString);

    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);    
    const wallet = new ethers.Wallet(privateKey, provider);

    const swapRouterAddress = '0x2626664c2603336E57B271c5C0b26F421741e481'; // Base
    const tokenContract = new Contract(tokenAddress, erc20Abi, wallet);

    const approvalResponse = await callContractMethod(
        tokenContract,
        'approve',
        [ swapRouterAddress, MaxUint256 ],
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

async function isInfiniteApproval(privateKey, tokenAddress, providerUrl) {
    const erc20Abi = loadAbi('erc20.json');

    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const { wallet, walletAddress } = initializeWallet(provider, privateKey);
    const swapRouterAddress = '0x2626664c2603336E57B271c5C0b26F421741e481'; // Base
    const tokenContract = new Contract(tokenAddress, erc20Abi, wallet);

    const allowance = await tokenContract.allowance(walletAddress, swapRouterAddress);

    return allowance === MaxUint256;
}

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

async function executeSwap(
    contract,
    params,
    gasPrice,
    nonce,
    shouldWait = true
  ) {
    try {
      // build overrides
      const overrides = { gasPrice, nonce };
      console.error(`🔧 executeSwap overrides:`, overrides);
  
      // send the tx
      const tx = await contract.exactInputSingle(params, overrides);
  
      // optionally wait for on‐chain confirmation
      if (shouldWait) {
        await tx.wait();
      }
  
      return { success: true, hash: tx.hash, nonce: tx.nonce };
    } catch (error) {
      console.error('Swap execution error:', error);
      return { success: false, error };
    }
  }

async function buy(privateKey, amountIn, tokenOut, tokenIn, tokenInDecimals, feeTier, providerUrl) {
    return await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, providerUrl);
}

async function sell(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, providerUrl) {
    return await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOut, providerUrl);
}

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

    /*
    if (result.success) {
        return { success: true, txHash: result.txHash, nonce: nonce };
    } else {
        return { success: false, error: result.error, nonce: nonce };
    }
    */
}

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

    /*
    if (result.success) {
        return { success: true, txHash: result.txHash, nonce: nonce };
    } else {
        if (result.error.transaction) {
            const txHash = ethers.keccak256(result.error.transaction);
        }
        return { success: false, error: result.error, txHash: txHash, nonce: nonce };
    }
    */
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

async function getMaxAmountIn(price, poolAddress, tokenInDecimals, tokenOutDecimals, providerUrl) {
    const priceRaw = ethers.parseUnits(price, Number(tokenOutDecimals));
    
    const pool = new ethers.Contract(poolAddress, loadAbi('uniswapv3pool.json'), new ethers.JsonRpcProvider(providerUrl, CHAIN_ID));
    const liquidity = await pool.liquidity();

    const tokenOutCapacity = liquidity * priceRaw / BigInt(10 ** tokenOutDecimals);
    const tokenInCapacity = tokenOutCapacity * BigInt(10 ** tokenInDecimals) / priceRaw;
    const maxAmountInWei = (tokenInCapacity * BigInt(2)) / BigInt(3);
    
    return ethers.formatUnits(maxAmountInWei, Number(tokenInDecimals));
}

async function getPoolData(tokenA, tokenADecimals, tokenB, tokenBDecimals, poolAddress, providerUrl) {
    const tokenADec = Number(tokenADecimals);
    const tokenBDec = Number(tokenBDecimals);
    
    if (isNaN(tokenADec) || isNaN(tokenBDec) || tokenADec < 0 || tokenBDec < 0) {
      throw new Error("Invalid decimals");
    }
  
    const uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    
    const [sortedToken0, sortedToken1] = sortTokens(tokenA, tokenB);
    const token0Decimals = tokenA.toLowerCase() === sortedToken0.toLowerCase() ? tokenADec : tokenBDec;
    const token1Decimals = tokenA.toLowerCase() === sortedToken0.toLowerCase() ? tokenBDec : tokenADec;
    
    const poolContract = new ethers.Contract(poolAddress, uniswapV3PoolAbi, provider);
    const [slot0, liquidity] = await Promise.all([poolContract.slot0(), poolContract.liquidity()]);
    const { tick } = slot0;
  
    // Price calculation (tokenA per tokenB)
    const rawPrice = (1.0001 ** Number(tick)) / (10 ** (token0Decimals - token1Decimals));
    const price = tokenA.toLowerCase() === sortedToken0.toLowerCase() ? rawPrice : 1 / rawPrice;
    const formattedPrice = price.toFixed(token1Decimals);
    const priceWei = ethers.parseUnits(formattedPrice, token1Decimals);
  
    // Max amount in calculation (tokenA as tokenIn, tokenB as tokenOut)
    const tokenOutCapacity = liquidity * priceWei / BigInt(10 ** token1Decimals);
    const tokenInCapacity = tokenOutCapacity * BigInt(10 ** tokenADec) / priceWei;
    const maxAmountInWei = (tokenInCapacity * BigInt(2)) / BigInt(3); // Safety factor ~1.5
    
    return {
      price: formattedPrice,
      maxAmountIn: ethers.formatUnits(maxAmountInWei, tokenADec)
    };
}

async function getTransactionReceipt(txHash, decimals, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);

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

/**
 * Converts ETH to WETH when a user creates a bot.
 * Keeps a small amount of ETH for gas based on percentage
 * @param {string} privateKey - Private key of the bot wallet
 * @param {string} providerUrl - URL for the Base network provider
 * @param {string} ethAmountToConvert - Amount of ETH to convert to WETH (in ETH, not wei)
 * @param {number} ethReservePercentage - Percentage of specified amount to keep for gas (default 1%)
 * @returns {Promise<Object>} - Transaction results
 */
async function convertETHToWETH(privateKey, providerUrl, ethAmountToConvert, ethReservePercentage = 1) {
    const WETH_ADDRESS = '0x4200000000000000000000000000000000000006'; // WETH on Base
    const WETH_ABI = loadAbi('weth.json');

    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const { wallet, walletAddress } = initializeWallet(provider, privateKey);
    
    // Get current ETH balance
    const ethBalance = await provider.getBalance(walletAddress);
    
    if (ethBalance <= 0n) {
        return {
            success: false,
            error: {
                message: "No ETH balance to convert",
                code: "INSUFFICIENT_BALANCE"
            }
        };
    }
    
    // Convert the provided amount to wei
    const amountToConvertWei = ethers.parseEther(ethAmountToConvert.toString());
    
    // Check if we have enough ETH
    if (amountToConvertWei > ethBalance) {
        return {
            success: false,
            error: {
                message: "Requested conversion amount exceeds available ETH balance",
                code: "INSUFFICIENT_BALANCE",
                available: ethers.formatEther(ethBalance),
                requested: ethAmountToConvert
            }
        };
    }
    
    // Calculate amount to reserve for gas based on percentage
    const ethToReserve = (amountToConvertWei * BigInt(ethReservePercentage)) / BigInt(100);
    const ethToConvert = amountToConvertWei - ethToReserve;
    
    // Estimate gas for the deposit transaction
    const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, wallet);
    const gasPrice = await calculateGasPrice(provider);
    const gasLimit = BigInt(60000); // Conservative estimate for WETH deposit
    const gasCost = gasPrice * gasLimit;
    
    // Ensure we have enough for gas
    if (ethToReserve < gasCost) {
        console.warn(`Warning: Reserved ETH (${ethers.formatEther(ethToReserve)}) may not be enough for gas (${ethers.formatEther(gasCost)})`);
    }
    
    if (ethToConvert <= 0n) {
        return {
            success: false,
            error: {
                message: "Amount to convert too low after gas reserve",
                code: "INSUFFICIENT_AMOUNT_AFTER_RESERVE"
            }
        };
    }
    
    try {
        // Call the deposit function on WETH contract (converts ETH to WETH)
        const tx = await wethContract.deposit({ 
            value: ethToConvert,
            gasPrice: gasPrice,
            gasLimit: gasLimit
        });
        
        const receipt = await tx.wait();
        
        return {
            success: true,
            txHash: tx.hash,
            amountConverted: ethers.formatEther(ethToConvert),
            ethReserved: ethers.formatEther(ethToReserve)
        };
    } catch (error) {
        console.error("Error converting ETH to WETH:", error.message);
        return {
            success: false,
            error: {
                message: error.message,
                reason: error.reason || 'Unknown reason',
                code: error.code || 'UNKNOWN_ERROR'
            }
        };
    }
}

async function convertWETHToETH(privateKey, providerUrl, wethAmountToConvert) {
    const WETH_ADDRESS = '0x4200000000000000000000000000000000000006'; // WETH on Base
    const WETH_ABI = loadAbi('weth.json'); // Make sure you have the WETH ABI in your contracts folder
    
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const { wallet, walletAddress } = initializeWallet(provider, privateKey);
    
    // Create WETH contract instance
    const wethContract = new ethers.Contract(WETH_ADDRESS, WETH_ABI, wallet);
    
    // Get current WETH balance
    const wethBalance = await wethContract.balanceOf(walletAddress);
    
    if (wethBalance <= 0n) {
        return {
            success: false,
            error: {
                message: "No WETH balance to convert",
                code: "INSUFFICIENT_BALANCE"
            }
        };
    }
    
    // Validate and convert the requested amount to wei
    if (!wethAmountToConvert) {
        return {
            success: false,
            error: {
                message: "WETH amount to convert must be specified",
                code: "MISSING_AMOUNT"
            }
        };
    }
    
    const amountToConvert = ethers.parseEther(wethAmountToConvert.toString());
    
    // Check if requested amount exceeds balance
    if (amountToConvert > wethBalance) {
        return {
            success: false,
            error: {
                message: "Requested conversion amount exceeds available WETH balance",
                code: "INSUFFICIENT_BALANCE",
                available: ethers.formatEther(wethBalance),
                requested: wethAmountToConvert
            }
        };
    }
    
    // Calculate gas for the withdrawal transaction
    const gasPrice = await calculateGasPrice(provider);
    const gasLimit = BigInt(60000); // Conservative estimate for WETH withdraw
    
    try {
        // Call the withdraw function on WETH contract (converts WETH to ETH)
        const tx = await wethContract.withdraw(amountToConvert, {
            gasPrice: gasPrice,
            gasLimit: gasLimit
        });
        
        const receipt = await tx.wait();
        
        return {
            success: true,
            txHash: tx.hash,
            amountConverted: ethers.formatEther(amountToConvert)
        };
    } catch (error) {
        console.error("Error converting WETH to ETH:", error.message);
        return {
            success: false,
            error: {
                message: error.message,
                reason: error.reason || 'Unknown reason',
                code: error.code || 'UNKNOWN_ERROR'
            }
        };
    }
}

async function getSwapAmounts(txHash, poolAddress, decimals0, decimals1, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const receipt  = await provider.getTransactionReceipt(txHash);
    //if (!receipt) throw new Error("Receipt not found");
    if (!receipt) return null;

    const uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');
    const iface = new ethers.Interface(uniswapV3PoolAbi);
    // Grab the EventFragment
    const swapEvent = iface.getEvent("Swap");
    const swapTopic = swapEvent.topicHash; // :contentReference[oaicite:0]{index=0}

    // Filter for the Swap log by topic
    const swapLog = receipt.logs.find(
        (log) =>
            log.address.toLowerCase() === poolAddress.toLowerCase() &&
            log.topics[0] === swapTopic
    );
    if (!swapLog) throw new Error("Swap event not found");

    // Decode the args
    const { amount0, amount1 } = iface.parseLog(swapLog).args;

    // Figure out “in” vs “out” by sign
    
    let amountIn, amountOut;
    /*
    if (amount0 < 0n) {
        amountOut  = ethers.formatUnits(-amount0, Number(decimals0));
        amountIn = ethers.formatUnits(amount1, Number(decimals1));
    } else {
        amountOut  = ethers.formatUnits(-amount1, Number(decimals1));
        amountIn = ethers.formatUnits(amount0, Number(decimals0));
    }*/

    if (amount0 < 0n) {
        // token0 was sent out
        amountOut = ethers.formatUnits(-amount0, Number(decimals0));
        amountIn  = ethers.formatUnits(amount1, Number(decimals1));
    } else {
        // token1 was sent out
        amountOut = ethers.formatUnits(-amount1, Number(decimals0)); // <-- use decimals0 here
        amountIn  = ethers.formatUnits(amount0, Number(decimals1));
    }

    return {
        amountIn,
        amountOut,
        status:      receipt.status,
        blockNumber: receipt.blockNumber,
        gasUsed:     receipt.gasUsed.toString()
    };
}
  
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

async function clearNonce(privateKey, nonceToClear, providerUrl, maxFeePerGasString, maxPriorityFeePerGasString) {
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const wallet = new ethers.Wallet(privateKey, provider);

    const baseMaxFee = maxFeePerGasString ? BigInt(maxFeePerGasString) : 0n;
    const baseTip    = maxPriorityFeePerGasString ? BigInt(maxPriorityFeePerGasString) : 0n;

    // Double the gas fees
    const bumpedPriority = baseTip * 2n;
    const bumpedMaxFee   = baseMaxFee * 2n;

    try {
        const tx = await wallet.sendTransaction({
            to:                   wallet.address,
            value:                0n,
            nonce:                nonceToClear,
            maxPriorityFeePerGas: bumpedPriority,
            maxFeePerGas:         bumpedMaxFee,
        });

        await tx.wait(1);

        return { success: true, txHash: tx.hash, nonce: tx.nonce };
    } catch (error) {
        return {
            success: false,
            nonce: nonceToClear,
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

module.exports = {
    getBalance,
    getTransactionCount,
    getPendingNonce,
    getTokenBalance,
    getTokenDetails,
    getQuote,
    getQuoteFormatted,
    swap,
    buy,
    sell,
    quoteMeetsMinimum,
    buyWithMinAmount,
    sellWithMinAmount,
    getTokenPrice,
    findMostLiquidPool,
    getPriceFromPool,
    getMaxAmountIn,
    getPoolData,
    getTransactionReceipt,
    getWalletAddress,
    generateWallet,
    convertETHToWETH,
    convertWETHToETH,
    getSwapAmounts,
    infiniteApprove,
    isInfiniteApproval,
    getGasPrice,
    getGasFees,
    clearNonce,
    sendErc20
};
