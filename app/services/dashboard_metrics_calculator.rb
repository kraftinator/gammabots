# app/services/dashboard_metrics_calculator.rb
class DashboardMetricsCalculator
  def self.call
    new.call
  end

  def call
    @active_bots = Bot.active.default_bots
    @eth_price_usd = get_eth_price_in_usd
    {
      active_bots: @active_bots.count,
      tvl_cents: calculate_tvl * @eth_price_usd * 100,
      volume_24h_cents: calculate_24h_volume * @eth_price_usd * 100,
      strategies_count: Strategy.count,
      total_profits_cents: calculate_total_profits * @eth_price_usd * 100,
      trades_executed: calculate_trades_executed
    }
  end

  private

  def calculate_tvl
    total_eth = @active_bots.sum(&:current_value)
    total_eth
  end

  def calculate_24h_volume
    recent_trades = Trade.joins(:bot)
                         .where(bot: Bot.default_bots)
                         .where(executed_at: 24.hours.ago..Time.current)
                         .where(status: 'completed')

    total_eth_volume = recent_trades.sum(&:total_value)
    total_eth_volume
  end

  def calculate_total_profits
    cycle_profits = Trade.joins(:bot)
                         .where(bot: Bot.default_bots)
                         .where(status: 'completed')
                         .where('executed_at >= ?', Date.new(2025, 7, 1))  # Added date filter
                         .group(:bot_cycle_id)
                         .having("COUNT(CASE WHEN trade_type = 'buy' THEN 1 END) >= 1")
                         .having("COUNT(CASE WHEN trade_type = 'sell' THEN 1 END) >= 1")
                         .select("
                           bot_cycle_id,
                           SUM(CASE WHEN trade_type = 'sell' THEN amount_out ELSE 0 END) - 
                           SUM(CASE WHEN trade_type = 'buy' THEN amount_in ELSE 0 END) as cycle_profit
                         ")

    total_profit_eth = cycle_profits.map(&:cycle_profit).select { |profit| profit > 0 }.sum
    total_profit_eth
  end

  def calculate_trades_executed
    Trade.joins(:bot)
         .where(bot: Bot.default_bots)
         .where(status: 'completed')
         .where('executed_at >= ?', Date.new(2025, 7, 1))
         .count
  end

  def get_eth_price_in_usd
    chain = @active_bots.first&.chain
    return 0 if chain.nil?
    
    base_token = Token.find_by(chain: chain, symbol: 'USDC')
    quote_token = Token.find_by(chain: chain, symbol: 'WETH')
    token_pair = TokenPair.find_by(chain: chain, base_token: base_token, quote_token: quote_token)
    
    price = token_pair.latest_price
    1 / price  # Convert USDC/WETH to USD/ETH
  end
end