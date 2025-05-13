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
    begin
      transaction_receipt = EthersService.get_transaction_receipt(trade.tx_hash,  trade.bot.token_pair, provider_url)
    rescue StandardError => e
      BotEvent.create!(
        bot: trade.bot,
        event_type: 'receipt_failure',
        payload: {
          class:       "TradeConfirmationService",
          method:      "confirm_buy_trade",
          trade_id:    trade.id,
          tx_hash:     trade.tx_hash,
          error_class: e.class.name,
          message:     e.message
        }
      )
      trade.update!(status: :failed)
      return
    end

    return unless transaction_receipt

    amount_in = BigDecimal(transaction_receipt["amountIn"].to_s)
    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    unless valid_transaction?(transaction_receipt, amount_in, amount_out)
      update_trade(trade, amount_in, amount_out, nil, transaction_receipt, :failed)
      return
    end

    trade_price = amount_in / amount_out

    update_trade(trade, amount_in, amount_out, trade_price, transaction_receipt)
    trade.bot.process_trade(trade.reload)
  end

  def self.confirm_sell_trade(trade, provider_url)
    begin
      transaction_receipt = EthersService.get_transaction_receipt(trade.tx_hash, trade.bot.token_pair, provider_url)
    rescue StandardError => e
      BotEvent.create!(
        bot: trade.bot,
        event_type: 'receipt_failure',
        payload: {
          class:       "TradeConfirmationService",
          method:      "confirm_sell_trade",
          trade_id:    trade.id,
          tx_hash:     trade.tx_hash,
          error_class: e.class.name,
          message:     e.message
        }
      )
      trade.update!(status: :failed)
      return
    end

    return unless transaction_receipt

    amount_in = BigDecimal(transaction_receipt["amountIn"].to_s)
    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    unless valid_transaction?(transaction_receipt, amount_in, amount_out)
      update_trade(trade, amount_in, amount_out, nil, transaction_receipt, :failed)
      return
    end

    trade_price = amount_out / amount_in

    update_trade(trade, amount_in, amount_out, trade_price, transaction_receipt)
    
    trade.reload
    
    trade.bot.process_trade(trade)
    #trade.bot.process_trade(trade.reload)
  end

  def self.valid_transaction?(transaction_receipt, amount_in, amount_out)
    transaction_receipt["status"] == 1 && amount_in.positive? && amount_out.positive?
  end

  def self.update_trade(trade, amount_in, amount_out, price, transaction_receipt, status=:completed)
    trade.update!(
      amount_in: amount_in,
      amount_out: amount_out,
      price: price,
      status: status,
      block_number: transaction_receipt["blockNumber"],
      gas_used: transaction_receipt["gasUsed"],
      confirmed_at: Time.current
    )
  end
end
