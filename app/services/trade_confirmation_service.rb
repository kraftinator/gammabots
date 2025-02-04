class TradeConfirmationService
  def self.confirm_trade(trade, provider_url)
    return unless trade.pending?

    if trade.buy?
      confirm_buy_trade(trade, provider_url)
    else
      confirm_sell_trade(trade, provider_url)
    end
  end

  private

  def self.confirm_buy_trade(trade, provider_url)
    decimals = trade.bot.token_pair.base_token.decimals
    transaction_receipt = EthersService.get_transaction_receipt(trade.tx_hash, decimals, provider_url)
    return unless transaction_receipt

    amount_in = BigDecimal(transaction_receipt["amountIn"].to_s)
    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    return unless valid_transaction?(transaction_receipt, amount_out)

    trade_price = trade.bot.quote_token_amount / amount_out

    update_trade(trade, amount_in, amount_out, trade_price, transaction_receipt)
    trade.bot.process_trade(trade.reload)
  end

  def self.confirm_sell_trade(trade, provider_url)
    decimals = trade.bot.token_pair.quote_token.decimals
    transaction_receipt = EthersService.get_transaction_receipt(trade.tx_hash, decimals, provider_url)
    return unless transaction_receipt

    amount_in = BigDecimal(transaction_receipt["amountIn"].to_s)
    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    return unless valid_transaction?(transaction_receipt, amount_out)

    trade_price = amount_out / trade.bot.base_token_amount

    update_trade(trade, amount_in, amount_out, trade_price, transaction_receipt)
    trade.bot.process_trade(trade.reload)
  end

  def self.valid_transaction?(transaction_receipt, amount_out)
    transaction_receipt["status"] == 1 && amount_out.positive?
  end

  def self.update_trade(trade, amount_in, amount_out, price, transaction_receipt)
    trade.update!(
      amount_in: amount_in,
      amount_out: amount_out,
      price: price,
      status: :completed,
      block_number: transaction_receipt["blockNumber"],
      gas_used: transaction_receipt["gasUsed"],
      confirmed_at: Time.current
    )
  end
end
