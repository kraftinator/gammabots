class TradeExecutionService
  def self.buy(bot, min_amount_out, provider_url)
    puts "========================================================"
    puts "TradeExecutionService::buy"
    puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, min_amount_out: #{min_amount_out.to_s}"
    puts "========================================================"

    quote_token_amount = bot.first_cycle? ? 
      bot.current_cycle.quote_token_amount : bot.current_cycle.quote_token_amount * 0.9999999999

    result = EthersService.buy_with_min_amount(
      bot.user.wallet_for_chain(bot.chain),
      #bot.current_cycle.quote_token_amount * 0.9999999999, # Amount to spend
      quote_token_amount, # Amount to spend
      bot.token_pair.quote_token.contract_address, # Token used for buying
      bot.token_pair.base_token.contract_address,  # Token being bought
      bot.token_pair.quote_token.decimals,
      bot.token_pair.base_token.decimals,
      bot.token_pair.fee_tier,
      min_amount_out,
      provider_url
    )

    puts "******************** result[:nonce]: #{result["nonce"]}"
    
    if result["success"]
      puts "Swap (buy) successful! Transaction Hash: #{result["txHash"]}"
      trade = Trade.create!(
        bot: bot,
        trade_type: :buy,
        tx_hash: result["txHash"],
        status: :pending,
        executed_at: Time.current
      )
      puts "Trade created: #{trade.id}"

      #TradeConfirmationService.confirm_trade(trade, provider_url)
    else
      reason = result.dig("error", "reason")
      event_type = "trade_failed"
      BotEvent.create!(
        bot:        bot,
        event_type: event_type,
        payload: {
          class:           "TradeExecutionService",
          method:          "buy",
          reason:           reason,
          attempted_amount: bot.current_cycle.quote_token_amount,
          min_amount_out:   min_amount_out,
          error:            result["error"]
        }
      )

      puts "========================================================"
      puts "TradeExecutionService::buy - Swap failed"
      puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, min_amount_out: #{min_amount_out.to_s}"
      puts "ERROR: #{result}"
      puts "========================================================"
    end
  end

  def self.sell(bot, base_token_amount, min_amount_out, provider_url)
    puts "========================================================"
    puts "Calling TradeExecutionService::sell"
    puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, base_token_amount: #{base_token_amount.to_s} min_amount_out: #{min_amount_out.to_s}"
    puts "========================================================"
    #puts "Token Amount to Sell: #{base_token_amount} #{bot.token_pair.base_token.symbol}"

    # Log the pool data
    #result = EthersService.get_pool_data(bot.token_pair, provider_url)
    #max_amount_in = EthersService.get_max_amount_in(bot.token_pair, provider_url)
    #puts "Max Amount In: #{max_amount_in} #{bot.token_pair.base_token.symbol}"
    
    result = EthersService.sell_with_min_amount(
      bot.user.wallet_for_chain(bot.chain),
      base_token_amount * 0.9999999999,  # Amount to sell
      bot.token_pair.base_token.contract_address,  # Token being sold
      bot.token_pair.quote_token.contract_address, # Token being received
      bot.token_pair.base_token.decimals,
      bot.token_pair.quote_token.decimals,
      bot.token_pair.fee_tier,
      min_amount_out,
      provider_url
    )

    puts "******************** result[:nonce]: #{result["nonce"]}"

    if result["success"]
      puts "Swap (sell) successful! Transaction Hash: #{result["txHash"]}"

      trade = Trade.create!(
        bot: bot,
        trade_type: :sell,
        tx_hash: result["txHash"],
        status: :pending,
        executed_at: Time.current
      )

      puts "Trade created: #{trade.id}"
      #TradeConfirmationService.confirm_trade(trade, provider_url)
      trade
    else
      reason = result.dig("error", "reason")
      event_type = "trade_failed"
      BotEvent.create!(
        bot:        bot,
        event_type: event_type,
        payload: {
          class:           "TradeExecutionService",
          method:          "sell",
          reason:           reason,
          attempted_amount: base_token_amount,
          min_amount_out:   min_amount_out,
          error:            result["error"]
        }
      )

      puts "========================================================"
      puts "TradeExecutionService::sell - Swap failed"
      puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, base_token_amount: #{base_token_amount.to_s} min_amount_out: #{min_amount_out.to_s}"
      puts "ERROR: #{result}"
      puts "========================================================"
      nil
    end
  end
end
