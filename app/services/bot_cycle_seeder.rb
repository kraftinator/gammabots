class BotCycleSeeder
  # Seeds the first cycle using bot configuration.
  # Raises on failure so the caller can retry.
  def self.seed!(bot)
    raise ArgumentError, "bot must be active" unless bot&.status == 'active'

    token_pair          = bot.token_pair
    moving_avg_minutes  = bot.moving_avg_minutes # or wherever you store it
    amount_eth          = bot.initial_buy_amount # BigDecimal ETH used as quote side

    current_price = token_pair.latest_price
    moving_avg    = token_pair.moving_average(moving_avg_minutes.to_i)

    bot.bot_cycles.create!(
      started_at: Time.current,
      quote_token_amount: amount_eth,
      created_at_price: current_price,
      lowest_price_since_creation: current_price,
      lowest_moving_avg_since_creation: moving_avg
    )
  end
end