class TradeExecutionService
  def self.buy(bot, provider_url)
    puts "Token Amount: #{bot.quote_token_amount}"
    #provider_url = ProviderUrlService.get_provider_url(bot.chain.name)

    tx_hash = EthersService.buy(
      bot.user.wallet_for_chain(bot.chain).private_key,
      bot.quote_token_amount, # Amount to spend
      bot.token_pair.base_token.contract_address,  # Token being bought
      bot.token_pair.quote_token.contract_address, # Token used for buying
      bot.token_pair.quote_token.decimals,
      provider_url
    )
    
    #puts "Bot #{bot.id} executed buy. TX Hash: #{tx_hash}"
    puts "Bot #{bot.id} executed buy: Spent #{bot.quote_token_amount} #{bot.token_pair.quote_token.symbol}, Received #{bot.token_pair.base_token.symbol}. TX Hash: #{tx_hash}"

    trade = Trade.create!(
      bot: bot,
      trade_type: :buy,
      tx_hash: tx_hash,
      status: :pending,
      executed_at: Time.current
    )

    TradeConfirmationService.confirm_trade(trade, provider_url)
    trade
  end
end
