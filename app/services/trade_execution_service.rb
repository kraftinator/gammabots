class TradeExecutionService
  def self.buy(bot, min_amount_out, provider_url)
    puts "Token Amount: #{bot.quote_token_amount}"

    result = EthersService.buy_with_min_amount(
      bot.user.wallet_for_chain(bot.chain).private_key,
      bot.quote_token_amount, # Amount to spend
      bot.token_pair.quote_token.contract_address, # Token used for buying
      bot.token_pair.base_token.contract_address,  # Token being bought
      bot.token_pair.quote_token.decimals,
      bot.token_pair.base_token.decimals,
      bot.token_pair.fee_tier,
      min_amount_out,
      provider_url
    )
    
    if result["swapped"]
      puts "Swapped!"
      trade = Trade.create!(
        bot: bot,
        trade_type: :buy,
        tx_hash: result["txHash"],
        status: :pending,
        executed_at: Time.current
      )

      TradeConfirmationService.confirm_trade(trade, provider_url)
    else
      puts "No swap!"
    end
  end

  def self.sell(bot, base_token_amount, min_amount_out, provider_url)
    puts "Token Amount: #{base_token_amount}"
    
    result = EthersService.sell_with_min_amount(
      bot.user.wallet_for_chain(bot.chain).private_key,
      base_token_amount,  # Amount to sell
      bot.token_pair.base_token.contract_address,  # Token being sold
      bot.token_pair.quote_token.contract_address, # Token being received
      bot.token_pair.base_token.decimals,
      bot.token_pair.quote_token.decimals,
      bot.token_pair.fee_tier,
      min_amount_out,
      provider_url
    )

    if result["swapped"]
      puts "Swapped!"

      trade = Trade.create!(
        bot: bot,
        trade_type: :sell,
        tx_hash: result["txHash"],
        status: :pending,
        executed_at: Time.current
      )

      TradeConfirmationService.confirm_trade(trade, provider_url)
    else
      puts "No swap!"
    end
  end
end
