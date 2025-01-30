class TradingStrategy
  def initialize(bot)
    @bot = bot
    @current_price = bot.token_pair.latest_price
    @provider_url = ProviderUrlService.get_provider_url(bot.chain.name)
  end

  def process
    if @bot.initial_buy_made?
      # Run strategy
    else
      perform_initial_buy
    end
  end

  private

  def perform_initial_buy
    #return unless @bot.quote_token_amount.positive?

    tx_hash = TradeExecutionService.buy(@bot)
    #return unless tx_hash # Stop if buy failed

    # Update bot state after buying
    #base_token_purchased = @bot.quote_token_amount / @current_price

    #@bot.update!(
    #  initial_buy_amount: base_token_purchased,
    #  base_token_amount: base_token_purchased,
    #  initial_buy_price: @current_price,
    #  highest_price_since_buy: @current_price,
    #  lowest_price_since_buy: @current_price,
    #  last_traded_at: Time.current
    #)

    #puts "Bot #{@bot.id} performed initial buy: #{base_token_purchased} #{@bot.token_pair.base_token.symbol} at #{@current_price}"
  end
end
