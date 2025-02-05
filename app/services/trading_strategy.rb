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
    if @current_price <= @bot.initial_buy_price * 0.80
      TradeExecutionService.sell(@bot, @bot.base_token_amount, @provider_url)
      @bot.update!(active: false)
      return
    end

    sell_trade_count = @bot.trades.where(trade_type: "sell").count

    if @current_price >= @bot.initial_buy_price * 1.20 && sell_trade_count == 0
      TradeExecutionService.sell(@bot, @bot.base_token_amount * 0.25, @provider_url)
      return
    end

    if @current_price >= @bot.initial_buy_price * 1.50 && sell_trade_count == 1
      TradeExecutionService.sell(@bot, @bot.base_token_amount * 0.25, @provider_url)
      return
    end
  
    if @current_price <= @bot.highest_price_since_initial_buy * 0.80 && sell_trade_count == 2
      TradeExecutionService.sell(@bot, @bot.base_token_amount, @provider_url)
      @bot.update!(active: false)
    end
  end

  def has_recovered_investment?
    @bot.quote_token_amount >= @bot.initial_buy_amount
  end  

  def perform_initial_buy
    TradeExecutionService.buy(@bot, @provider_url)
  end
end
