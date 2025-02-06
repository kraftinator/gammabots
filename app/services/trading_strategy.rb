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

  def strategy_1
    # Strategy 1: Stop-Loss
    # If current price falls to 80% or less of the initial buy price,
    # sell all tokens and deactivate the bot.
    if @current_price <= @bot.initial_buy_price * 0.80
      TradeExecutionService.sell(@bot, @bot.base_token_amount, @provider_url)
      @bot.update!(active: false)
      return
    end

    sell_trade_count = @bot.trades.where(trade_type: "sell").count

    # Strategy 2: Profit Capture on First Sell
    # Conditions:
    #   - No sell trades have been executed yet (sell_trade_count == 0)
    #   - The highest price since initial buy is at least 100% above the initial buy price
    #   - The current price is at or below an effective threshold:
    #       effective_threshold = max(90% of highest price, 200% of initial buy)
    # Action:
    #   - Sell 50% of the position
    if sell_trade_count == 0 && 
       @bot.highest_price_since_initial_buy >= @bot.initial_buy_price * 2.0
      
      effective_threshold = [@bot.highest_price_since_initial_buy * 0.90, @bot.initial_buy_price * 2.0].max

      if @current_price <= effective_threshold
        TradeExecutionService.sell(@bot, @bot.base_token_amount * 0.50, @provider_url)
        return
      end
    end

    # Strategy 3: Trailing Sell After First Trade
    # Conditions:
    #   - At least one sell trade has been executed (sell_trade_count > 0)
    #   - The current price has dropped to 90% or less of the highest price since the last trade
    # Action:
    #   - Sell 25% of the position
    if sell_trade_count > 0 && @current_price <= @bot.highest_price_since_last_trade * 0.90
      TradeExecutionService.sell(@bot, @bot.base_token_amount * 0.25, @provider_url)
      return
    end
  end

  def has_recovered_investment?
    @bot.quote_token_amount >= @bot.initial_buy_amount
  end  

  def perform_initial_buy
    TradeExecutionService.buy(@bot, @provider_url)
  end
end
