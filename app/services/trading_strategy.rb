class TradingStrategy
  def initialize(bot, provider_url)
    @bot = bot
    @current_price = bot.token_pair.latest_price
    @provider_url = provider_url
  end

  def process
    if @bot.initial_buy_made?
      @bot.update_prices(@current_price)
      @bot.reload
      default_strategy
    else
      perform_initial_buy
    end
  end

  private

  def default_strategy
    stop_loss_price = @bot.initial_buy_price * 0.80

    if @current_price <= stop_loss_price
      puts "Stop loss. Sell everything!"
      TradeExecutionService.sell(@bot, @bot.base_token_amount, @provider_url)
      @bot.update!(active: false)
    end
  end

  def perform_initial_buy
    TradeExecutionService.buy(@bot, @provider_url)
  end
end
