# app/services/dashboard_metrics_calculator.rb
class DashboardMetricsCalculator
  def self.call
    new.call
  end

  def call
    @active_bots = Bot.active.default_bots.visible
    chain = @active_bots.first&.chain
    @eth_price_usd = TokenPriceService.get_eth_price_in_usd(chain)

    {
      active_bots: @active_bots.count,
      tvl_cents: (calculate_tvl_eth * @eth_price_usd * 100).to_i,
      volume_24h_cents: (calculate_24h_volume_eth * @eth_price_usd * 100).to_i,
      strategies_count: Strategy.canonical.count,
      total_profits_cents: (calculate_total_profits_eth * @eth_price_usd * 100).to_i,
      trades_executed: calculate_trades_executed,

      # NEW cached blobs
      popular_tokens_json: calculate_popular_tokens,
      recent_activity_json: calculate_recent_activity,
      top_performers_json: calculate_top_performers
    }
  end

  private

  # --- existing numeric metrics ---

  def calculate_tvl_eth
    # If current_value is computed in Ruby, you’re stuck iterating.
    # If you can derive TVL from DB later, great — but leaving it as-is for now:
    @active_bots.sum(&:current_value)
  end

  def calculate_24h_volume_eth
    recent_trades = Trade.joins(:bot)
                         .where(bot: Bot.default_bots.visible)
                         .where(executed_at: 24.hours.ago..Time.current)
                         .where(status: "completed")
                         .includes(bot: [:token_pair, :user], bot_cycle: [])

    recent_trades.sum(&:total_value)
  end

  def calculate_total_profits_eth
    cycle_profits = Trade.joins(:bot)
                         .where(bot: Bot.default_bots.visible)
                         .where(status: "completed")
                         .where("executed_at >= ?", Date.new(2025, 7, 1))
                         .group(:bot_cycle_id)
                         .having("COUNT(CASE WHEN trade_type = 'buy' THEN 1 END) >= 1")
                         .having("COUNT(CASE WHEN trade_type = 'sell' THEN 1 END) >= 1")
                         .select("
                           bot_cycle_id,
                           SUM(CASE WHEN trade_type = 'sell' THEN amount_out ELSE 0 END) -
                           SUM(CASE WHEN trade_type = 'buy' THEN amount_in ELSE 0 END) AS cycle_profit
                         ")

    cycle_profits.map(&:cycle_profit).select { |p| p > 0 }.sum
  end

  def calculate_trades_executed
    Trade.joins(:bot)
         .where(bot: Bot.default_bots.visible)
         .where(status: "completed")
         .where("executed_at >= ?", Date.new(2025, 7, 1))
         .count
  end

  # --- NEW: cached feeds ---

  def calculate_popular_tokens
    # Top 4 by TVL among active bots.
    # If current_value is Ruby-computed, still OK because N is active bots only.
    token_tvls_eth =
      @active_bots
        .group_by { |bot| bot.token_pair.base_token.symbol }
        .transform_values { |bots| bots.sum(&:current_value) }
        .sort_by { |_sym, eth| -eth }
        .first(4)

    token_tvls_eth.map do |symbol, eth|
      {
        token_symbol: symbol,
        tvl_usd: (eth * @eth_price_usd).round(2)
      }
    end
  end

  def calculate_recent_activity
    trades = Trade.joins(:bot)
                  .where(bot: Bot.default_bots.visible)
                  .where(status: "completed")
                  .order(executed_at: :desc)
                  .limit(8)
                  .includes(bot: [:user, :strategy, { token_pair: :base_token }], bot_cycle: [])

    trades.map do |trade|
      token_amount = trade.buy? ? trade.amount_out : trade.amount_in
      bot = trade.bot
      user = bot.user
      

      performance_pct =
        if trade.sell? && trade.bot_cycle
          (trade.bot_cycle.profit_fraction(include_profit_withdrawals: true) * 100).round(1)
        end

      {
        owner_username: user.farcaster_username,
        owner_avatar_url: user.farcaster_avatar_url,
        action: trade.trade_type.capitalize,
        amount: token_amount.round(0),
        token_symbol: trade.bot.token_pair.base_token.symbol,
        token_name: trade.bot.token_pair.base_token.name,
        token_address: trade.bot.token_pair.base_token.contract_address,
        strategy_id: trade.bot.strategy.nft_token_id,
        moving_average: bot.moving_avg_minutes,
        bot_id: bot.id,
        display_name: bot.display_name,
        bot_owner_id: user.id,
        performance_pct: performance_pct,
        executed_at: trade.executed_at.iso8601,
        trades: bot.completed_trade_count,
        active_seconds: calculate_active_seconds(bot)
      }
    end
  end

  def calculate_top_performers
    # Eligible bots = default+visible bots that had at least one COMPLETED sell in last 30d.
    # Then rank by the SAME bot-level profit % you show in "My Bots".
    bots = Bot.default_bots.visible
              .joins(:trades)
              .where(trades: { status: "completed", trade_type: "sell" })
              .where("trades.executed_at >= ?", 30.days.ago)
              .distinct
              .includes(:strategy, :user, token_pair: :base_token)

    ranked = bots.map do |bot|
      pct = bot.profit_percentage(include_profit_withdrawals: true).to_f
      [bot, pct]
    end
    .select { |_bot, pct| pct.positive? }
    .sort_by { |_bot, pct| -pct }
    .first(3)

    ranked.map.with_index(1) do |(bot, pct), idx|
      user = bot.user
      token = bot.token_pair&.base_token

      {
        rank: idx,
        bot_id: bot.id.to_s,
        display_name: bot.display_name,
        bot_owner_id: user.id.to_s,
        token_symbol: token&.symbol,
        token_name: token&.name,
        token_address: token&.contract_address,
        strategy_id: bot.strategy&.nft_token_id&.to_s,
        moving_average: bot.moving_avg_minutes,
        owner_username: user.farcaster_username,
        owner_avatar_url: user.farcaster_avatar_url,
        # IMPORTANT: same metric as "My Bots"
        performance_pct: pct.round(2),
        trades: bot.completed_trade_count,
        active_seconds: calculate_active_seconds(bot)
      }
    end
  end

  private

  def calculate_active_seconds(bot)
    end_time =
      if bot.active?
        Time.current
      else
        bot.last_action_at || bot.updated_at
      end

    (end_time - bot.created_at).to_i
  end
end