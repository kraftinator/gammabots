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
      win_rate_bps: calculate_win_rate
    }
  end

  private

  def calculate_tvl
    total_eth = @active_bots.sum(&:current_value)
    total_eth
  end

  def calculate_24h_volume
    recent_trades = Trade.joins(:bot)
                         .where(bot: @active_bots)
                         .where(executed_at: 24.hours.ago..Time.current)
                         .where(status: 'completed')

    total_eth_volume = recent_trades.sum(&:total_value)
    total_eth_volume
  end

  def calculate_total_profits
    cycles = BotCycle.joins(:bot)
                     .where(bot: Bot.default_bots)
                     .where.not(ended_at: nil)

    total_profit_eth = cycles.sum do |cycle|
      # Calculate current profit in the cycle
      current_profit = cycle.quote_token_amount - cycle.initial_buy_amount
      
      # Add any profit that was already taken
      total_profit = current_profit + cycle.profit_taken
      
      # Only include if it's actually profitable
      total_profit > 0 ? total_profit : 0
    end

    total_profit_eth
  end

  def calculate_win_rate
    cycles = BotCycle.joins(:bot)
                   .where(bot: Bot.default_bots)
                   .where.not(ended_at: nil)

    return 0.0 if cycles.count == 0

    profitable_cycles_count = cycles.count(&:profitable?)
    win_rate_percentage = profitable_cycles_count.to_f / cycles.count * 100
    (win_rate_percentage * 100).round # Convert to basis points
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