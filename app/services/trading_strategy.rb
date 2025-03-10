class TradingStrategy
  def initialize(bot, provider_url)
    @bot = bot
    @current_price = bot.token_pair.latest_price
    @provider_url = provider_url
  end

  def process
    @bot.update_prices(@current_price)      
    @bot.reload
    strategy_interpreter = TradingStrategyInterpreter.new(@bot.strategy_json, @bot.strategy_variables)
    strategy_interpreter.execute
  end

  #def process
  #  if @bot.initial_buy_made?
  #    @bot.update_prices(@current_price)
  #    @bot.reload
  #    strategy_interpreter = TradingStrategyInterpreter.new(@bot.strategy_json, @bot.strategy_variables)
  #    strategy_interpreter.execute
  #  else
  #    perform_initial_buy
  #  end
  #end

  #private

  #def has_recovered_investment?
  #  @bot.quote_token_amount >= @bot.initial_buy_amount
  #end  

  #def perform_initial_buy
  #  TradeExecutionService.buy(
  #    @bot, 
  #    @bot.min_amount_out_for_initial_buy, 
  #    @provider_url
  #  )
  #end
end
