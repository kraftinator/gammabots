class TradeConfirmationService
  def self.confirm_trade(trade)
    return unless trade.pending?

    transaction_receipt = EthersService.get_transaction_receipt(trade.tx_hash)
    return unless transaction_receipt && transaction_receipt["blockNumber"]

    base_token_amount_received = transaction_receipt["amount_out"].to_d
    return unless base_token_amount_received.positive?

    #trade.bot.with_lock do
      #initial_buy_price = trade.bot.quote_token_amount / base_token_amount_received

      #trade.bot.update!(
      #  base_token_amount: trade.bot.base_token_amount + base_token_amount_received,
      #  initial_buy_price: initial_buy_price,
      #  last_traded_at: Time.current
      #)

      #trade.update!(status: :complete)

      #puts "Trade #{trade.id} confirmed: Bought #{base_token_amount_received} #{trade.bot.token_pair.base_token.symbol} at price #{initial_buy_price} #{trade.bot.token_pair.quote_token.symbol}"
    #end
  end
end
