// Aggregate exports from all modularized files
module.exports = {
  // --- Core ---
  ...require('./core/wallet'),
  ...require('./core/gas'),

  // --- Tokens ---
  ...require('./tokens/erc20'),
  ...require('./tokens/weth'),

  // --- DEX ---
  ...require('./dex/uniswap'),

  // --- Receipts & Analytics ---
  ...require('./receipts/transactions'),

  // --- Shared Utilities ---
  ...require('./utils/helpers')
};