class TradeConfirmationService
  def self.confirm_trade(trade, provider_url)
    return unless trade.pending?

    transaction_receipt = EthersService.get_transaction_receipt(trade.tx_hash, provider_url)
    return unless transaction_receipt

    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    status = transaction_receipt["status"]
    block_number = transaction_receipt["blockNumber"]
    gas_used = transaction_receipt["gasUsed"]

    # Ensure the trade was successful and amount_out is valid
    return unless status == 1 && amount_out.positive?

    if trade.buy?
      trade_price = trade.bot.quote_token_amount / amount_out

      trade.update!(
        amount: amount_out, 
        price: trade_price,
        total_value: amount_out * trade_price,
        status: :completed,
        block_number: block_number,
        gas_used: gas_used
      )

      trade.bot.process_trade(trade.reload)
    else
      # Do something else
    end
    
  end
end
