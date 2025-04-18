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

function loadAbi(fileName) {
    const abiPath = path.join(__dirname, '../contracts', fileName);
    return JSON.parse(fs.readFileSync(abiPath, 'utf8'));
}

function initializeWallet(provider, privateKey) {
    const wallet = new ethers.Wallet(privateKey, provider);
    return { wallet, walletAddress: wallet.address };
}

function getWalletAddress(privateKey, providerUrl) {
    const provider = new ethers.JsonRpcProvider(providerUrl);
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
    
    const provider = new ethers.JsonRpcProvider(providerUrl);
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

    //return ethers.formatUnits(amountOut, Number(tokenOutDecimals));
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

async function swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOut, providerUrl) {
    const erc20Abi = loadAbi('erc20.json');
    const swapRouterAbi = loadAbi('swaprouter.json');

    const provider = new ethers.JsonRpcProvider(providerUrl);
    const { wallet, walletAddress } = initializeWallet(provider, privateKey);

    const swapRouterAddress = '0x2626664c2603336E57B271c5C0b26F421741e481'; // Base
    const swapRouterContract = new Contract(swapRouterAddress, swapRouterAbi, wallet);
    const tokenInContract = new Contract(tokenIn, erc20Abi, wallet);

    // Convert amount to trade into wei
    const formattedAmount = parseFloat(amountIn).toFixed(Number(tokenInDecimals));
    const amountInWei = ethers.parseUnits(formattedAmount, Number(tokenInDecimals));

    const gasPrice = await calculateGasPrice(provider);

    const allowance = await tokenInContract.allowance(walletAddress, swapRouterAddress);
    if (allowance < amountInWei) {
        await callContractMethod(tokenInContract, 'approve', [swapRouterAddress, amountInWei], gasPrice);
    }

    const swapDeadline = Math.floor(Date.now() / 1000 + 60 * 60);
    const swapTxInputs = {
        tokenIn: tokenIn,
        tokenOut: tokenOut,
        fee: feeTier,
        recipient: walletAddress,
        deadline: BigInt(swapDeadline),
        amountIn: amountInWei,
        //amountOutMinimum: 0n,
        amountOutMinimum: minAmountOut,
        sqrtPriceLimitX96: 0n
    };

    const swapTxResponse = await callContractMethod(
        swapRouterContract,
        'exactInputSingle',
        [swapTxInputs],
        gasPrice
    );

    //return swapTxResponse.hash;

    if (swapTxResponse.hash) {
        return { success: true, txHash: swapTxResponse.hash };
    } else {
        // Catch STF errors
        return {
            success: false,
            error: swapTxResponse.error
        };
    }

    /*
    if (swapTxResponse.success) {
        return { success: true, txHash: swapTxResponse.tx.hash };
    } else {
        // Catch STF errors
        return {
            success: false,
            error: swapTxResponse.error
        };
    }
        */
}

async function buy(privateKey, amountIn, tokenOut, tokenIn, tokenInDecimals, feeTier, providerUrl) {
    return await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, providerUrl);
}

async function sell(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, providerUrl) {
    return await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOut, providerUrl);
}

async function buyWithMinAmount(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, tokenOutDecimals, feeTier, minAmountOut, providerUrl) {
    // Convert minAmountOut
    const formattedMinOut = parseFloat(minAmountOut).toFixed(Number(tokenOutDecimals));
    const minAmountOutRaw = ethers.parseUnits(formattedMinOut, Number(tokenOutDecimals));
  
    // Get quote
    const quoteRaw = await getQuote(tokenIn, tokenOut, feeTier, amountIn, tokenInDecimals, tokenOutDecimals, providerUrl);
  
    // Compare the raw quoted amount with our minimum acceptable output.
    if (BigInt(quoteRaw) >= BigInt(minAmountOutRaw)) {
      // Quote greater than or equal to our mininum amount. Proceed with swap.

      const result = await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOutRaw, providerUrl);

      if (result.success) {
        return { success: true, txHash: result.txHash };
      } else {
        return { success: false, error: result.error };
      }
      //const txHash = await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOutRaw, providerUrl);
      //return { swapped: true, txHash: txHash };

    } else {
      const formattedQuote = ethers.formatUnits(quoteRaw, Number(tokenInDecimals));
      return { success: false, txHash: null, quote: formattedQuote, min_amount_out: minAmountOut };
    }
}
  
async function sellWithMinAmount(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, tokenOutDecimals, feeTier, minAmountOut, providerUrl) {
    // Convert minAmountOut
    const formattedMinOut = parseFloat(minAmountOut).toFixed(Number(tokenOutDecimals));
    const minAmountOutRaw = ethers.parseUnits(formattedMinOut, Number(tokenOutDecimals));

    // Get quote
    const quoteRaw = await getQuote(tokenIn, tokenOut, feeTier, amountIn, tokenInDecimals, tokenOutDecimals, providerUrl);

    if (quoteRaw >= minAmountOutRaw) {
        // Quote greater than or equal to our mininum amount. Proceed with swap.
        //const txHash = await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOutRaw, providerUrl);
        const result = await swap(privateKey, amountIn, tokenIn, tokenOut, tokenInDecimals, feeTier, minAmountOutRaw, providerUrl);
        if (result.success) {
            return { success: true, txHash: result.txHash };
          } else {
            return { success: false, error: result.error };
          }
        //return { swapped: true, txHash: txHash };
    } else {
        const formattedQuote = ethers.formatUnits(quoteRaw, Number(tokenInDecimals));
        return { success: false, txHash: null, quote: formattedQuote, min_amount_out: minAmountOut };
    }
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

async function getMaxAmountIn(price, poolAddress, tokenInDecimals, tokenOutDecimals, providerUrl) {
    const priceRaw = ethers.parseUnits(price, Number(tokenOutDecimals));
    
    const pool = new ethers.Contract(poolAddress, loadAbi('uniswapv3pool.json'), new ethers.JsonRpcProvider(providerUrl));
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
    const provider = new ethers.JsonRpcProvider(providerUrl);
    
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

    const provider = new ethers.JsonRpcProvider(providerUrl);
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
    
    const provider = new ethers.JsonRpcProvider(providerUrl);
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
    const provider = new ethers.JsonRpcProvider(providerUrl);
    const receipt  = await provider.getTransactionReceipt(txHash);
    if (!receipt) throw new Error("Receipt not found");

    const uniswapV3PoolAbi = loadAbi('uniswapv3pool.json');
    const iface = new ethers.Interface(uniswapV3PoolAbi);
    // Grab the EventFragmen
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
    if (amount0 < 0n) {
        amountOut  = ethers.formatUnits(-amount0, Number(decimals0));
        amountIn = ethers.formatUnits(amount1, Number(decimals1));
    } else {
        amountOut  = ethers.formatUnits(-amount1, Number(decimals1));
        amountIn = ethers.formatUnits(amount0, Number(decimals0));
    }

    return {
        amountIn,
        amountOut,
        status:      receipt.status,
        blockNumber: receipt.blockNumber,
        gasUsed:     receipt.gasUsed.toString()
    };
}

module.exports = {
    getBalance,
    getTransactionCount,
    getTokenBalance,
    getTokenDetails,
    getQuote,
    getQuoteFormatted,
    swap,
    buy,
    sell,
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
    getSwapAmounts
};
