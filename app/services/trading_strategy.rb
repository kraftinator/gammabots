class TradingStrategy
  def initialize(bot, provider_url)
    @bot = bot
    @current_price = bot.token_pair.latest_price
    @provider_url = provider_url
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
    TradeExecutionService.buy(@bot, @provider_url)
  end
end
