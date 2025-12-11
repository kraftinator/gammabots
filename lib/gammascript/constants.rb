# app/lib/gammascript/constants.rb
# frozen_string_literal: true

# ==============================================================
#  Gammabots :: Gammascript Field Constants
#
#  Provides bidirectional mapping between:
#    - compact 3-char Gammascript abbreviations used on-chain
#    - human-readable field names used in the validator, UI, etc.
#
#  Example:
#    VALID_FIELDS["bcn"]        # => "buyCount"
#    VALID_FIELDS["buyCount"]   # => "bcn"
# ==============================================================

module Gammascript
  module Constants
    VALID_FIELDS = {
      # --- Core Prices ---
      "cpr" => "currentPrice",
      "currentPrice" => "cpr",

      "ppr" => "prevPrice",
      "prevPrice" => "ppr",

      "rhi" => "rollingHigh",
      "rollingHigh" => "rhi",

      "ibp" => "initBuyPrice",
      "initBuyPrice" => "ibp",

      "lbp" => "listedBuyPrice",
      "listedBuyPrice" => "lbp",

      # --- Counts / Amounts / Config ---
      "bcn" => "buyCount",
      "buyCount" => "bcn",

      "scn" => "sellCount",
      "sellCount" => "scn",

      "bta" => "tokenAmt",
      "tokenAmt" => "bta",

      "mam" => "movingAvg",
      "movingAvg" => "mam",

      # --- Indicators ---
      "pdi" => "priceDiv",
      "priceDiv" => "pdi",

      # Momentum (same short & long) ---
      "mom" => "mom",

      # --- Volatility (same short & long) ---
      "vst" => "vst",
      "vlt" => "vlt",
      "ssd" => "ssd",
      "lsd" => "lsd",

      # --- Prices & Extremes ---
      "cap" => "creationPrice",
      "creationPrice" => "cap",

      "hps" => "highSinceCreate",
      "highSinceCreate" => "hps",

      "lps" => "lowSinceCreate",
      "lowSinceCreate" => "lps",

      "hip" => "highInitBuy",
      "highInitBuy" => "hip",

      "hlt" => "highLastTrade",
      "highLastTrade" => "hlt",

      "lip" => "lowInitBuy",
      "lowInitBuy" => "lip",

      "llt" => "lowLastTrade",
      "lowLastTrade" => "llt",

      "lsp" => "lastSellPrice",
      "lastSellPrice" => "lsp",

      # --- Moving Averages ---
      # MA codes themselves are the long form too
      "cma" => "cma",
      "lma" => "lma",
      "tma" => "tma",

      "pcm" => "prevCMA",
      "prevCMA" => "pcm",

      "plm" => "prevLMA",
      "prevLMA" => "plm",

      # CMA extremes
      "lmc" => "lowCMASinceCreate",
      "lowCMASinceCreate" => "lmc",

      "hma" => "highCMASinceInit",
      "highCMASinceInit" => "hma",

      "lmi" => "lowCMASinceInit",
      "lowCMASinceInit" => "lmi",

      "hmt" => "highCMASinceTrade",
      "highCMASinceTrade" => "hmt",

      "lmt" => "lowCMASinceTrade",
      "lowCMASinceTrade" => "lmt",

      # --- Profitability ---
      "lcp" => "profitLastCycle",
      "profitLastCycle" => "lcp",

      "scp" => "profitSecondCycle",
      "profitSecondCycle" => "scp",

      "bpp" => "botProfit",
      "botProfit" => "bpp",

      # --- Time-based ---
      "lta" => "minSinceTrade",
      "minSinceTrade" => "lta",

      "lba" => "minSinceBuy",
      "minSinceBuy" => "lba",

      "crt" => "minSinceCreate",
      "minSinceCreate" => "crt"
    }.freeze

    FIELD_LABELS = {
      "currentPrice"         => "Current Price",
      "prevPrice"            => "Previous Price",
      "rollingHigh"          => "Rolling High",
      "initBuyPrice"         => "Initial Buy Price",
      "listedBuyPrice"       => "Listed Buy Price",

      "buyCount"             => "Buy Count",
      "sellCount"            => "Sell Count",
      "tokenAmt"             => "Token Amount",
      "movingAvg"            => "Moving Average (Minutes)",

      "priceDiv"             => "Price Diversity",
      "mom"                  => "Momentum",
      "vst"                  => "Volatility (Short)",
      "vlt"                  => "Volatility (Long)",
      "ssd"                  => "Std Dev (Short)",
      "lsd"                  => "Std Dev (Long)",

      "highInitBuy"          => "High Since Initial Buy",
      "lowInitBuy"           => "Low Since Initial Buy",
      "highSinceCreate"      => "High Since Creation",
      "lowSinceCreate"       => "Low Since Creation",
      "highLastTrade"        => "High Since Last Trade",
      "lowLastTrade"         => "Low Since Last Trade",
      "lastSellPrice"        => "Last Sell Price",

      "prevCMA"              => "Previous CMA",
      "prevLMA"              => "Previous LMA",
      "lowCMASinceCreate"    => "Low CMA (Since Creation)",
      "highCMASinceInit"     => "High CMA (Since Initial Buy)",
      "lowCMASinceInit"      => "Low CMA (Since Initial Buy)",
      "highCMASinceTrade"    => "High CMA (Since Last Trade)",
      "lowCMASinceTrade"     => "Low CMA (Since Last Trade)",

      "profitLastCycle"      => "Profit (Last Cycle)",
      "profitSecondCycle"    => "Profit (2nd Cycle)",
      "botProfit"            => "Total Bot Profit",

      "minSinceTrade"        => "Minutes Since Last Trade",
      "minSinceBuy"          => "Minutes Since Last Buy",
      "minSinceCreate"       => "Minutes Since Creation"
    }
  end
end