// zero_ex.js
const { ethers, Contract } = require('ethers');
const { initializeWallet, loadAbi } = require('../utils/helpers');
const CHAIN_ID = 8453; // Base chain
const WETH_BASE = '0x4200000000000000000000000000000000000006';

/**
 * Fetch a 0x v2 quote for an ERC-20 → ERC-20 swap on Base.
 *
 * Params (object):
 * - sellToken          (string)  ERC-20 address (e.g., WETH: 0x4200…0006 on Base)
 * - buyToken           (string)  ERC-20 address (e.g., USDC: 0x8335…2913 on Base)
 * - amount          (string|number) Human-readable sell amount (e.g., "0.0001")
 * - sellTokenDecimals  (number)  Decimals for sellToken (e.g., 18 for WETH)
 * - taker              (string)  Your wallet address (required by 0x on Base)
 * - apiKey             (string)  Your 0x API key
 * - slippageBps        (number)  Optional (default 100 = 1%)
 * - intentOnFilling    (boolean) Optional (default true)
 *
 * Returns:
 *   { success: true, quote: <0x JSON>, sellAmountWei: <string> } on success
 *   { success: false, error: <string>, status?: <number>, body?: <string> } on failure
 */
async function get0xQuote(
  sellToken,
  buyToken,
  amount,
  sellTokenDecimals,
  taker,
  apiKey,
  slippageBps = 100,
  intentOnFilling = true
) {
  try {
    if (!sellToken || !buyToken) throw new Error('sellToken and buyToken are required');
    if (!taker) throw new Error('taker address is required by 0x on Base');
    if (!apiKey) throw new Error('0x API key is required');

    // Convert human-readable to wei
    const sellAmountWei = ethers.parseUnits(String(amount), Number(sellTokenDecimals)).toString();

    // Normalize slippage
    const n = Number(slippageBps);
    const slippageBpsInt = Number.isFinite(n) ? Math.max(0, Math.floor(n)) : 100;

    const endpoint = 'https://api.0x.org/swap/allowance-holder/quote';
    const params = new URLSearchParams({
      chainId: String(CHAIN_ID),
      sellToken,
      buyToken,
      sellAmount: sellAmountWei,
      taker,
      intentOnFilling: intentOnFilling ? 'true' : 'false',
      slippageBps: String(slippageBpsInt)
    });

    const res = await fetch(`${endpoint}?${params.toString()}`, {
      method: 'GET',
      headers: {
        'accept': 'application/json',
        '0x-api-key': apiKey,
        '0x-version': 'v2'
      }
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      return {
        success: false,
        status: res.status,
        error: `0x quote request failed (${res.status})`,
        body
      };
    }

    const json = await res.json();
    return { success: true, quote: json, sellAmountWei };
  } catch (err) {
    return { success: false, error: err.message || String(err) };
  }
}

/**
 * Execute a 0x swap using the transaction payload returned by get0xQuote().
 *
 * @param {string} privateKey   - EOA private key (hex string)
 * @param {object} quote        - The full 0x quote JSON (i.e., result.quote from get0xQuote)
 * @param {number} nonce        - Nonce to use (optional; pass undefined to let the node pick)
 * @param {string} providerUrl  - RPC URL for Base
 *
 * @returns {Promise<{ success: boolean, error?: any, txHash?: string, nonce?: number, bumpNonce: boolean }>}
 */
async function execute0xSwap(privateKey, quote, nonce, providerUrl) {
  // Defensive checks
  if (!quote || !quote.transaction) {
    return { success: false, error: 'Missing quote.transaction', nonce, bumpNonce: false };
  }

  const txFields = quote.transaction;

  try {
    // Init provider + wallet (same pattern as uniswap.js)
    const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
    const { wallet } = initializeWallet(provider, privateKey);

    // Build tx request from 0x payload. Only include fields that exist.
    const txRequest = {
      to: txFields.to,
      data: txFields.data,
      // 0x may provide numeric strings; coerce to BigInt where applicable
      ...(txFields.value     ? { value:     ethers.toBigInt(txFields.value) }     : {}),
      ...(txFields.gas       ? { gasLimit:  ethers.toBigInt(txFields.gas) }       : {}),
      ...(txFields.gasPrice  ? { gasPrice:  ethers.toBigInt(txFields.gasPrice) }  : {}),
      ...(Number.isInteger(nonce) ? { nonce } : {})
    };

    const resp = await wallet.sendTransaction(txRequest);

    // Successful broadcast
    return {
      success: true,
      txHash: resp.hash,
      nonce:  nonce,
      bumpNonce: true, // we saw a hash, so caller can safely bump nonce for next tx
    };
  } catch (error) {
    // If ethers gives us a raw signed tx on failure, derive hash so caller can still bump nonce
    let txHash;
    if (error?.transaction) {
      try { txHash = ethers.keccak256(error.transaction); } catch (_) {}
    }

    return {
      success: false,
      error,
      txHash,
      nonce,
      bumpNonce: Boolean(txHash), // true if we recovered a signed tx hash
    };
  }
}

/**
 * Quote then broadcast a 0x swap on Base, returning staged results.
 *
 * @param {string} privateKey
 * @param {string} sellToken               ERC-20 address (e.g., WETH on Base)
 * @param {string} buyToken                ERC-20 address
 * @param {string|number} amount           human-readable (e.g., "0.0001")
 * @param {number} sellTokenDecimals       decimals for sellToken
 * @param {string} taker                   wallet address (0x requires on Base)
 * @param {string} apiKey                  0x API key
 * @param {string} providerUrl             RPC URL
 * @param {number} nonce                   REQUIRED
 * @param {number} [slippageBps=100]
 * @param {boolean} [intentOnFilling=true]
 *
 * @returns {Promise<object>} staged payload
 */
async function quoteAndSwap0x(
  privateKey,
  sellToken,
  buyToken,
  amount,
  sellTokenDecimals,
  taker,
  apiKey,
  providerUrl,
  nonce,
  slippageBps = 100,
  intentOnFilling = true
) {
  const parsedNonce = Number(nonce);
  if (!Number.isFinite(parsedNonce) || !Number.isInteger(parsedNonce)) {
    return {
      success: false,
      stage: 'quote',
      message: 'nonce is required (integer)',
      code: 'NONCE_REQUIRED',
      http_status: null,
      tx_hash: null,
      nonce: null,
      bumpNonce: false,
      allowance: null,
      raw: {}
    };
  }

  // 1) Quote
  const q = await get0xQuote(
    sellToken,
    buyToken,
    amount,
    sellTokenDecimals,
    taker,
    apiKey,
    slippageBps,
    intentOnFilling
  );

  if (!q.success) {
    return {
      success: false,
      stage: 'quote',
      message: q.error || '0x quote request failed',
      code: 'QUOTE_HTTP_ERROR',
      http_status: q.status ?? null,
      tx_hash: null,
      nonce: null,
      bumpNonce: false,
      allowance: null,
      raw: { body: q.body, status: q.status, error: q.error }
    };
  }

  const quote = q.quote;
  const sellAmountWei = q.sellAmountWei;
  const allowanceIssue = quote?.issues?.allowance;
  const allowanceActual = allowanceIssue?.actual;
  const allowanceSpender = allowanceIssue?.spender || quote?.allowanceTarget;

  // 2) Allowance check: stop and signal if insufficient
  try {
    const needsApproval =
      allowanceActual === '0' ||
      (typeof allowanceActual === 'string' && BigInt(allowanceActual) < BigInt(sellAmountWei));

    if (needsApproval) {
      return {
        success: false,
        stage: 'allowance',
        message: 'Approval required for spender',
        code: 'ALLOWANCE_REQUIRED',
        http_status: null,
        tx_hash: null,
        nonce: null,
        bumpNonce: false,
        allowance: {
          needsApproval: true,
          spender: allowanceSpender,
          token: sellToken,
          requiredAmountWei: sellAmountWei,
          actualAllowanceWei: allowanceActual ?? null
        },
        raw: {}
      };
    }
  } catch {
    // If parsing fails, be conservative and stop for approval
    return {
      success: false,
      stage: 'allowance',
      message: 'Approval required for spender',
      code: 'ALLOWANCE_REQUIRED',
      http_status: null,
      tx_hash: null,
      nonce: null,
      bumpNonce: false,
      allowance: {
        needsApproval: true,
        spender: allowanceSpender,
        token: sellToken,
        requiredAmountWei: sellAmountWei,
        actualAllowanceWei: allowanceActual ?? null
      },
      raw: {}
    };
  }

  // 3) Broadcast
  const exec = await execute0xSwap(privateKey, quote, parsedNonce, providerUrl);

  if (!exec.success) {
    return {
      success: false,
      stage: 'broadcast',
      message: (exec.error?.reason || exec.error?.message || 'Broadcast failed'),
      code: (exec.error?.code || 'BROADCAST_FAILED'),
      http_status: null,
      tx_hash: exec.txHash || null,
      nonce: String(parsedNonce),
      bumpNonce: !!exec.bumpNonce,
      allowance: null,
      raw: { error: exec.error }
    };
  }

  // 4) Success payload
  const sources =
    Array.isArray(quote?.route?.fills)
      ? quote.route.fills.map(f => ({ name: f.source, bps: f.proportionBps }))
      : [];

  return {
    success: true,
    stage: 'success',
    txHash: exec.txHash,
    nonce: nonce,
    sellAmountWei,
    buyAmount: quote?.buyAmount,
    minBuyAmount: quote?.minBuyAmount,
    route: { sources },
    networkFeeWei: quote?.totalNetworkFee,
    allowance: { needsApproval: false, spender: allowanceSpender },
    bumpNonce: true
  };
}

// ---------- helpers (private) ----------
async function fetchTokenDecimals(tokenAddress, providerUrl) {
  const erc20Abi = loadAbi('erc20.json');
  const provider = new ethers.JsonRpcProvider(providerUrl, CHAIN_ID);
  const c = new Contract(tokenAddress, erc20Abi, provider);
  const dec = await c.decimals();
  return Number(dec);
}

function impliedPriceFromQuote(quote, sellAmountWei, sellDecimals, buyDecimals) {
  // price = (buyAmount / 10^buyDec) / (sellAmount / 10^sellDec)
  const buy = BigInt(quote.buyAmount ?? '0');
  const sell = BigInt(sellAmountWei);
  if (sell === 0n) return null;
  // Use BigInt math then format as decimal string
  // scale both to 1e18 to keep precision
  const SCALE = 10n ** 18n;
  const buyScaled  = buy * SCALE / (10n ** BigInt(buyDecimals));
  const sellScaled = sell / (10n ** BigInt(sellDecimals));
  if (sellScaled === 0n) return null;
  const priceScaled = buyScaled / sellScaled; // in 1e18
  return ethers.formatUnits(priceScaled, 18);
}

function priceImpactBps(priceSmall, priceLarge) {
  // impact = (priceSmall - priceLarge) / priceSmall
  const ps = Number(priceSmall);
  const pl = Number(priceLarge);
  if (!Number.isFinite(ps) || ps <= 0 || !Number.isFinite(pl)) return null;
  const impact = (ps - pl) / ps;
  return Math.max(0, Math.round(impact * 10_000));
}

function extractSources(quote) {
  const fills = quote?.route?.fills;
  if (!Array.isArray(fills)) return [];
  return fills.map(f => ({ name: f.source, bps: f.proportionBps }));
}

function allowanceInfo(quote) {
  const allowance = quote?.issues?.allowance;
  return {
    spender: quote?.allowanceTarget || allowance?.spender || null,
    actual:  allowance?.actual ?? null
  };
}

async function isSellableViaReverseProbe(buyToken, buyTokenDecimals, taker, apiKey, providerUrl, slippageBps) {
  // Try selling 1 unit of the *buyToken* back to WETH to ensure it’s not buy-only
  const amountHuman = '1';
  const q = await get0xQuote(
    buyToken,
    WETH_BASE,
    amountHuman,
    buyTokenDecimals,
    taker,
    apiKey,
    slippageBps,
    true
  );
  return !!(q.success && q.quote?.liquidityAvailable);
}

// ---------- public orchestrator ----------
/**
 * Validate a WETH -> buyToken pair using 0x quotes (small & large) and optional reverse probe.
 *
 * @param {string} taker            // REQUIRED by 0x on Base
 * @param {string} buyToken
 * @param {string} providerUrl
 * @param {string} apiKey
 * @param {string|number} slippageBps
 * @param {string|number} probeSmallWeth  // human (e.g., "0.05")
 * @param {string|number} probeLargeWeth  // human (e.g., "0.5")
 * @param {boolean} [doReverseProbe=true]
 *
 * @returns {Promise<object>} verdict payload
 */
async function validateTokenPairWith0x(
  taker,
  buyToken,
  providerUrl,
  apiKey,
  slippageBps = 200,     // default 2%
  probeSmallWeth = '0.05',
  probeLargeWeth = '0.5',
  doReverseProbe = true
) {
  // Normalize slippage
  const n = Number(slippageBps);
  const slippageBpsInt = Number.isFinite(n) ? Math.max(0, Math.floor(n)) : 200; // default 2%

  // Known: WETH has 18 decimals on Base
  const sellToken = WETH_BASE;
  const sellTokenDecimals = 18;

  // Fetch buy token decimals once
  let buyTokenDecimals;
  try {
    buyTokenDecimals = await fetchTokenDecimals(buyToken, providerUrl);
  } catch (e) {
    return {
      success: false,
      stage: 'metadata',
      message: 'Failed to fetch token decimals',
      code: 'DECIMALS_LOOKUP_FAILED',
      raw: { error: e?.message }
    };
  }

  // --- small quote
  const qSmall = await get0xQuote(
    sellToken,
    buyToken,
    String(probeSmallWeth),
    sellTokenDecimals,
    taker,
    apiKey,
    slippageBpsInt,
    true
  );
  if (!qSmall.success) {
    return {
      success: false,
      stage: 'quote_small',
      message: qSmall.error || '0x quote (small) failed',
      code: 'QUOTE_SMALL_FAILED',
      raw: { status: qSmall.status, body: qSmall.body, error: qSmall.error }
    };
  }

  // --- large quote
  const qLarge = await get0xQuote(
    sellToken,
    buyToken,
    String(probeLargeWeth),
    sellTokenDecimals,
    taker,
    apiKey,
    slippageBpsInt,
    true
  );
  if (!qLarge.success) {
    return {
      success: false,
      stage: 'quote_large',
      message: qLarge.error || '0x quote (large) failed',
      code: 'QUOTE_LARGE_FAILED',
      raw: { status: qLarge.status, body: qLarge.body, error: qLarge.error }
    };
  }

  // Compute implied prices & impact
  const priceSmall = impliedPriceFromQuote(qSmall.quote, qSmall.sellAmountWei, sellTokenDecimals, buyTokenDecimals);
  const priceLarge = impliedPriceFromQuote(qLarge.quote, qLarge.sellAmountWei, sellTokenDecimals, buyTokenDecimals);
  const impactBps  = priceImpactBps(priceSmall, priceLarge);

  // Allowance + routing/tax signals
  const allowSmall = allowanceInfo(qSmall.quote);
  const allowLarge = allowanceInfo(qLarge.quote);
  const needsApproval =
    (allowSmall.actual === '0') ||
    (allowLarge.actual === '0');

  const sourcesSmall = extractSources(qSmall.quote);
  const sourcesLarge = extractSources(qLarge.quote);

  const buyTaxBps  = qSmall.quote?.tokenMetadata?.buyToken?.buyTaxBps ?? null;
  const sellTaxBps = qSmall.quote?.tokenMetadata?.sellToken?.sellTaxBps ?? null;

  // Optional reverse-probe to detect “buy-only”
  let reverseProbe = { attempted: false, sellable: null };
  if (doReverseProbe) {
    reverseProbe.attempted = true;
    try {
      reverseProbe.sellable = await isSellableViaReverseProbe(
        buyToken,
        buyTokenDecimals,
        taker,
        apiKey,
        providerUrl,
        slippageBpsInt
      );
    } catch {
      reverseProbe.sellable = null; // unknown
    }
  }

  // Basic heuristics for acceptance (you can tune these)
  const tooHighImpact = (impactBps != null && impactBps > 1_500); // >15%
  const obviouslyTaxed = (Number(buyTaxBps) > 300 || Number(sellTaxBps) > 300); // >3%
  const reverseBlocked = (reverseProbe.attempted && reverseProbe.sellable === false);

  const accept = !(tooHighImpact || obviouslyTaxed || reverseBlocked);

  return {
    success: true,
    verdict: accept ? 'accept' : 'reject',
    reasons: {
      tooHighImpact,
      obviouslyTaxed,
      reverseBlocked
    },
    metrics: {
      priceSmall,               // buy per 1 WETH at small size
      priceLarge,               // buy per 1 WETH at large size
      impactBps,
      networkFeeWeiSmall: qSmall.quote?.totalNetworkFee ?? null,
      networkFeeWeiLarge: qLarge.quote?.totalNetworkFee ?? null,
      buyTaxBps:  buyTaxBps != null ? String(buyTaxBps)  : null,
      sellTaxBps: sellTaxBps != null ? String(sellTaxBps) : null,
      sourcesSmall,
      sourcesLarge
    },
    allowance: {
      spender: allowSmall.spender || allowLarge.spender || null,
      needsApproval
    },
    reverseProbe
  };
}

/**
 * Fetch an indicative price from 0x (no slippage, read-only).
 *
 * All params are strings (Rails passes them as strings).
 * Returns { success: true, price: <string>, sellAmountWei, buyAmountWei } or { success: false, error }
 */
async function get0xPrice(sellToken, buyToken, amount, sellTokenDecimalsStr, buyTokenDecimalsStr, apiKey) {
  try {
    if (!sellToken || !buyToken) throw new Error('sellToken and buyToken are required');
    if (!apiKey) throw new Error('0x API key is required');

    let sellTokenDecimals = Number(sellTokenDecimalsStr);
    let buyTokenDecimals = Number(buyTokenDecimalsStr);

    // Convert human-readable to wei
    const sellAmountWei = ethers.parseUnits(String(amount), sellTokenDecimals).toString();

    const endpoint = 'https://api.0x.org/swap/allowance-holder/price';
    const params = new URLSearchParams({
      chainId: String(CHAIN_ID),
      sellToken,
      buyToken,
      sellAmount: sellAmountWei
    });

    const res = await fetch(`${endpoint}?${params.toString()}`, {
      method: 'GET',
      headers: {
        'accept': 'application/json',
        '0x-api-key': apiKey,
        '0x-version': 'v2'
      }
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      return { success: false, status: res.status, error: `0x price request failed (${res.status})`, body };
    }

    const json = await res.json();
    const buyAmount = BigInt(json.buyAmount ?? '0');
    const sellAmount = BigInt(json.sellAmount ?? '0');
    if (sellAmount === 0n) throw new Error('Invalid sellAmount (0) returned from 0x');

    // Compute price = (buyAmount / 10^buyDec) / (sellAmount / 10^sellDec)
    const price =
      Number(ethers.formatUnits(buyAmount, buyTokenDecimals)) /
      Number(ethers.formatUnits(sellAmount, sellTokenDecimals));

    const formattedPrice = price.toFixed(buyTokenDecimals);

    return {
      success: true,
      price: formattedPrice,
      sellAmountWei,
      buyAmountWei: json.buyAmount
    };
  } catch (err) {
    return { success: false, error: err.message || String(err) };
  }
}

module.exports = {
  get0xQuote,
  execute0xSwap,
  quoteAndSwap0x,
  validateTokenPairWith0x,
  get0xPrice
};