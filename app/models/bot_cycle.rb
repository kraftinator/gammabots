class BotCycle < ApplicationRecord
  belongs_to :bot
  has_many :trades

  def buy_count
    trades.where(trade_type: "buy", status: "completed").count
  end

  def sell_count
    trades.where(trade_type: "sell", status: "completed").count
  end

  def last_sell_price
    trades.where(trade_type: "sell", status: "completed").order(created_at: :desc).first&.price
  end

  def last_buy_at
    trades.where(trade_type: "buy", status: "completed").order(created_at: :desc).first&.created_at
  end

  def last_sell_at
    trades.where(trade_type: "sell", status: "completed").order(created_at: :desc).first&.created_at
  end

  def last_trade_at
    trades.where(status: "completed").order(created_at: :desc).first&.created_at
  end

  def initial_buy_made?
    initial_buy_amount > 0 && trades.where(trade_type: "buy", status: "completed").count > 0
  end

  def open?
    ended_at.nil?
  end

  def current_value
    total_value = base_token_amount * bot.token_pair.current_price
    total_value += quote_token_amount
    total_value
  end

  def profit_percentage
    # guard against divide-by-zero
    return 0.0 if initial_buy_amount.to_f.zero?

    # ((current – initial) / initial) × 100, rounded to 2 decimal places
    change    = current_value - initial_buy_amount.to_f
    percent   = change / initial_buy_amount.to_f * 100
    percent.round(2)
  end

  def profit_fraction
    return 0.0 if initial_buy_amount.to_f.zero?
    (current_value - initial_buy_amount.to_f) / initial_buy_amount.to_f
  end

  def previous_cycle
    bot.bot_cycles
       .where("created_at < ?", created_at)
       .order(created_at: :desc)
       .first
  end

  def strategy_variables(use_cached_price: false)
    token_pair = bot.token_pair
    moving_avg_minutes = bot.moving_avg_minutes
    {
      cpr: use_cached_price ? token_pair.current_price : token_pair.latest_price,
      ppr: token_pair.previous_price || Float::NAN,
      rhi: token_pair.rolling_high(moving_avg_minutes) || Float::NAN,
      ibp: initial_buy_price,
      bcn: buy_count,
      scn: sell_count,
      bta: base_token_amount,
      mam: moving_avg_minutes,
      vst: token_pair.volatility(moving_avg_minutes) || Float::NAN,
      vlt: token_pair.volatility(moving_avg_minutes*2) || Float::NAN,
      # prices
      lps: lowest_price_since_creation,
      hip: highest_price_since_initial_buy,
      hlt: highest_price_since_last_trade,
      lip: lowest_price_since_initial_buy,
      llt: lowest_price_since_last_trade,
      # moving averages
      cma: token_pair.moving_average(moving_avg_minutes) || Float::NAN,
      lma: token_pair.moving_average(moving_avg_minutes*2) || Float::NAN,
      tma: token_pair.moving_average(moving_avg_minutes*3) || Float::NAN,
      lmc: lowest_moving_avg_since_creation || Float::NAN,
      hma: highest_moving_avg_since_initial_buy,
      lmi: lowest_moving_avg_since_initial_buy,
      hmt: highest_moving_avg_since_last_trade,
      lmt: lowest_moving_avg_since_last_trade,
      # profitability
      lcp: previous_cycle&.profit_fraction.to_f || 0.0,
      bpp: bot.profit_fraction.to_f || 0.0,

      lta: last_trade_at,
      lba: last_buy_at,
      lsp: last_sell_price,
      crt: created_at,
      bot: bot,
      provider_url: bot.provider_url
    }
  end
end
