class TradingStrategy
  ALLOWED_METRIC_KEYS = %w[
    mam
    cpr
    ppr
    cma
    lma
    tma
    pcm
    plm
    rhi
    ndp
    nd2
    pdi
    mom
    ssd
    lsd
    vst
    vlt
  ].freeze

  def initialize(bot, provider_url)
    @bot = bot
    @current_price = bot.token_pair.latest_price
    @moving_average = bot.token_pair.moving_average(bot.moving_avg_minutes)
    @provider_url = provider_url
  end

  def process
    @bot.update_prices(@current_price, @moving_average)      
    @bot.reload

    strategy_variables = @bot.strategy_variables
    strategy_interpreter = TradingStrategyInterpreter.new(@bot.strategy_json, strategy_variables)
    strategy_interpreter.execute
    catch_metrics(strategy_variables) if @bot.catch_metrics?
  end

  private

  def catch_metrics(strategy_variables)
    symbol_keys = ALLOWED_METRIC_KEYS.map(&:to_sym)
    filtered   = strategy_variables.slice(*symbol_keys)
    metrics  = filtered.transform_values(&:to_s)
    @bot.bot_price_metrics.create!(price: @current_price, metrics: metrics)
  end

  #def process
  #  @bot.update_prices(@current_price, @moving_average)      
  #  @bot.reload
  #  strategy_interpreter = TradingStrategyInterpreter.new(@bot.strategy_json, @bot.strategy_variables)
  #  strategy_interpreter.execute
  #end
end
