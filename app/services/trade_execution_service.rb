class TradeExecutionService
  def self.buy(bot)
    #return unless bot.quote_token_amount.positive?
    puts "Token Amount: #{bot.quote_token_amount}"

    # Call ethers_utils.js via EthersService
    tx_hash = EthersService.buy(
      bot.user.wallet_for_chain(bot.chain).private_key,
      bot.quote_token_amount, # Amount to spend
      bot.token_pair.base_token.contract_address,  # Token being bought
      bot.token_pair.quote_token.contract_address, # Token used for buying
      bot.token_pair.quote_token.decimals,
      ProviderUrlService.get_provider_url(bot.chain.name)
    )
    
    puts "Bot #{bot.id} executed buy. TX Hash: #{tx_hash}"
    trade = Trade.create!(bot: bot, tx_hash: tx_hash['hash'], status: :pending)
    TradeConfirmationService.confirm_trade(trade)

    # Wait for transaction confirmation and get receipt
    #transaction_receipt = EthersService.get_transaction_receipt(tx_hash['hash'])
    #return unless transaction_receipt
    
    # Extract base_token_amount_received from receipt
    #base_token_amount_received = transaction_receipt["amount_out"]
    #return unless base_token_amount_received.to_d.positive?
    
    # Compute initial buy price
    #initial_buy_price = bot.quote_token_amount / base_token_amount_received.to_d
    
    # Update bot record
    #bot.update!(
    #  base_token_amount: bot.base_token_amount + base_token_amount_received.to_d,
    #  initial_buy_price: initial_buy_price,
    #  last_traded_at: Time.current
    #)

    #tx_hash
  end
end
