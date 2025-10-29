// zero_ex.js
const { ethers } = require('ethers');
const { initializeWallet } = require('../utils/helpers');
const CHAIN_ID = 8453; // Base chain

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

    const endpoint = 'https://api.0x.org/swap/allowance-holder/quote';
    const params = new URLSearchParams({
      chainId: String(CHAIN_ID),
      sellToken,
      buyToken,
      sellAmount: sellAmountWei,
      taker,
      intentOnFilling: intentOnFilling ? 'true' : 'false',
      slippageBps: String(slippageBps)
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

module.exports = {
  get0xQuote,
  execute0xSwap
};