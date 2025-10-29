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
#    VALID_FIELDS["bcn"]           # => "buyCount"
#    VALID_FIELDS["buyCount"]      # => "bcn"
# ==============================================================

module Gammascript
  module Constants
    VALID_FIELDS = {
      # --- Core ---
      "cpr" => "currentPrice",
      "currentPrice" => "cpr",

      "ppr" => "previousPrice",
      "previousPrice" => "ppr",

      "rhi" => "rollingHigh",
      "rollingHigh" => "rhi",

      "ibp" => "initialBuyPrice",
      "initialBuyPrice" => "ibp",

      "lbp" => "listedBuyPrice",
      "listedBuyPrice" => "lbp",

      "bcn" => "buyCount",
      "buyCount" => "bcn",

      "scn" => "sellCount",
      "sellCount" => "scn",

      "bta" => "tokenAmount",
      "tokenAmount" => "bta",

      "mam" => "movingAverageMinutes",
      "movingAverageMinutes" => "mam",

      # --- Indicators ---
      "pdi" => "priceDiversityIndicator",
      "priceDiversityIndicator" => "pdi",

      "mom" => "momentumRatio",
      "momentumRatio" => "mom",

      # --- Volatility ---
      "vst" => "shortVolatility",
      "shortVolatility" => "vst",

      "vlt" => "longVolatility",
      "longVolatility" => "vlt",

      "ssd" => "shortVolatilityStdDev",
      "shortVolatilityStdDev" => "ssd",

      "lsd" => "longVolatilityStdDev",
      "longVolatilityStdDev" => "lsd",

      # --- Prices & Extremes ---
      "cap" => "creationPrice",
      "creationPrice" => "cap",

      "hps" => "highestPriceSinceCreation",
      "highestPriceSinceCreation" => "hps",

      "lps" => "lowestPriceSinceCreation",
      "lowestPriceSinceCreation" => "lps",

      "hip" => "highestPriceSinceInitialBuy",
      "highestPriceSinceInitialBuy" => "hip",

      "hlt" => "highestPriceSinceLastTrade",
      "highestPriceSinceLastTrade" => "hlt",

      "lip" => "lowestPriceSinceInitialBuy",
      "lowestPriceSinceInitialBuy" => "lip",

      "llt" => "lowestPriceSinceLastTrade",
      "lowestPriceSinceLastTrade" => "llt",

      "lsp" => "lastSellPrice",
      "lastSellPrice" => "lsp",

      # --- Moving Averages ---
      "cma" => "currentMovingAverage",
      "currentMovingAverage" => "cma",

      "lma" => "longMovingAverage",
      "longMovingAverage" => "lma",

      "tma" => "tripleMovingAverage",
      "tripleMovingAverage" => "tma",

      "pcm" => "previousCurrentMovingAverage",
      "previousCurrentMovingAverage" => "pcm",

      "plm" => "previousLongMovingAverage",
      "previousLongMovingAverage" => "plm",

      "lmc" => "lowestMovingAverageSinceCreation",
      "lowestMovingAverageSinceCreation" => "lmc",

      "hma" => "highestMovingAverageSinceInitialBuy",
      "highestMovingAverageSinceInitialBuy" => "hma",

      "lmi" => "lowestMovingAverageSinceInitialBuy",
      "lowestMovingAverageSinceInitialBuy" => "lmi",

      "hmt" => "highestMovingAverageSinceLastTrade",
      "highestMovingAverageSinceLastTrade" => "hmt",

      "lmt" => "lowestMovingAverageSinceLastTrade",
      "lowestMovingAverageSinceLastTrade" => "lmt",

      # --- Profitability ---
      "lcp" => "lastCycleProfitFraction",
      "lastCycleProfitFraction" => "lcp",

      "scp" => "secondCycleProfitFraction",
      "secondCycleProfitFraction" => "scp",

      "bpp" => "botProfitFraction",
      "botProfitFraction" => "bpp",

      # --- Time-based ---
      "lta" => "minutesSinceLastTrade",
      "minutesSinceLastTrade" => "lta",

      "lba" => "minutesSinceLastBuy",
      "minutesSinceLastBuy" => "lba",

      "crt" => "minutesSinceCreation",
      "minutesSinceCreation" => "crt"
    }.freeze
  end
end