namespace :trades do
  
  desc "Get transaction receipt"
  # Usage:
  # rake trades:get_transaction_receipt["4"]
  task :get_transaction_receipt, [:trade_id] => :environment do |t, args|
    if args[:trade_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    trade = Trade.find(args[:trade_id])
    unless trade
      raise ArgumentError, "Invalid trade!"
    end

    provider_url = ProviderUrlService.get_provider_url(trade.bot.chain.name)
    decimals = trade.token_pair.base_token.decimals
    transaction_receipt = EthersService.get_transaction_receipt(trade.tx_hash, decimals, provider_url)

    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    status = transaction_receipt["status"]
    block_number = transaction_receipt["blockNumber"]
    gas_used = transaction_receipt["gasUsed"]

    token_pair = trade.bot.token_pair

    puts "Amount Out:   #{amount_out} #{token_pair.base_token.symbol}"
    puts "Status:       #{status}"
    puts "Block Number: #{block_number}"
    puts "Gas Used:     #{gas_used}"
  end
end