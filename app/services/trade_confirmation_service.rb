class TradeConfirmationService
  def self.confirm_trade(trade, provider_url)
    #return unless trade.pending?
    return :not_pending unless trade.pending?

    if trade.buy?
      confirm_buy_trade(trade, provider_url)
    else
      confirm_sell_trade(trade, provider_url)
    end
  end

  private

  def self.confirm_buy_trade(trade, provider_url)
    begin
      bot = trade.bot
      wallet_address = bot.user.wallet_for_chain(bot.chain).address
      token_pair = trade.token_pair
      sell_token = token_pair.quote_token
      buy_token = token_pair.base_token
      transaction_receipt = EthersService.read_swap_receipt_erc20(trade.tx_hash, wallet_address, sell_token.contract_address, sell_token.decimals, buy_token.contract_address, buy_token.decimals, provider_url)
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
      # Important: leave the trade as `pending` so the job can retry.
      Rails.logger.warn "[TradeConfirmationService] temporary receipt failure for Trade##{trade.id}: #{e.class} - #{e.message}"
      #return
      return :temporary_error
    end

    # If still no receipt (e.g. tx not mined yet), leave it pending; job will retry.
    #unless transaction_receipt
    #  BotEvent.create!(
    #    bot: trade.bot,
    #    event_type: 'receipt_missing',
    #    payload: {
    #      class:  "TradeConfirmationService",
    #      method: "confirm_buy_trade",
    #      trade_id: trade.id,
    #      tx_hash:  trade.tx_hash
    #    }
    #  )
    #  return
    #end

    if transaction_receipt.nil?
      # Known tx, not mined yet
      BotEvent.create!(
        bot: trade.bot,
        event_type: 'receipt_pending',
        payload: {
          class:  "TradeConfirmationService",
          method: "confirm_buy_trade",
          trade_id: trade.id,
          tx_hash: trade.tx_hash
        }
      )
      return :pending
    end

    if transaction_receipt.is_a?(Hash) && transaction_receipt["status"] == "not_found"
      BotEvent.create!(
        bot: trade.bot,
        event_type: 'receipt_not_found',
        payload: {
          class:  "TradeConfirmationService",
          method: "confirm_buy_trade",
          trade_id: trade.id,
          tx_hash: trade.tx_hash,
          message: "RPC does not recognize tx hash"
        }
      )
      return :not_found
      #trade.update!(
      #  status: :failed,
      #  confirmed_at: Time.current,
      #  price: token_pair.current_price
      #)
      #return :failed
    end

    amount_in = BigDecimal(transaction_receipt["amountIn"].to_s)
    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    unless valid_transaction?(transaction_receipt, amount_in, amount_out)
      update_trade(trade, amount_in, amount_out, token_pair.current_price, transaction_receipt, :failed)
      return :failed
    end

    trade_price = amount_in / amount_out

    update_trade(trade, amount_in, amount_out, trade_price, transaction_receipt)
    
    trade.reload
    trade.bot.process_trade(trade)
    return :completed
  end

  def self.confirm_sell_trade(trade, provider_url)
    begin
      bot = trade.bot
      wallet_address = bot.user.wallet_for_chain(bot.chain).address
      token_pair = trade.token_pair
      sell_token = token_pair.base_token
      buy_token = token_pair.quote_token
      transaction_receipt = EthersService.read_swap_receipt_erc20(trade.tx_hash, wallet_address, sell_token.contract_address, sell_token.decimals, buy_token.contract_address, buy_token.decimals, provider_url)
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
      #trade.update!(status: :failed, price: trade.token_pair.current_price)
      Rails.logger.warn "[TradeConfirmationService] temporary receipt failure for Trade##{trade.id}: #{e.class} - #{e.message}"
      return :temporary_error
    end

    # If still no receipt (e.g. tx not mined yet), leave it pending; job will retry.
    #unless transaction_receipt
    #  BotEvent.create!(
    #    bot: trade.bot,
    #    event_type: 'receipt_missing',
    #    payload: {
    #      class:  "TradeConfirmationService",
    #      method: "confirm_sell_trade",
    #      trade_id: trade.id,
    #      tx_hash: trade.tx_hash,
    #      message: "Receipt unavailable (transaction not mined yet)"
    #    }
    #  )
    #  return
    #end

    if transaction_receipt.nil?
      # Known tx, not mined yet
      BotEvent.create!(
        bot: trade.bot,
        event_type: 'receipt_pending',
        payload: {
          class:  "TradeConfirmationService",
          method: "confirm_sell_trade",
          trade_id: trade.id,
          tx_hash: trade.tx_hash
        }
      )
      return :pending
    end

    if transaction_receipt.is_a?(Hash) && transaction_receipt["status"] == "not_found"
      BotEvent.create!(
        bot: trade.bot,
        event_type: 'receipt_not_found',
        payload: {
          class:  "TradeConfirmationService",
          method: "confirm_sell_trade",
          trade_id: trade.id,
          tx_hash: trade.tx_hash,
          message: "RPC does not recognize tx hash"
        }
      )
      return :not_found
      #trade.update!(
      #  status: :failed,
      #  confirmed_at: Time.current,
      #  price: token_pair.current_price
      #)
      #return :failed
    end

    amount_in = BigDecimal(transaction_receipt["amountIn"].to_s)
    amount_out = BigDecimal(transaction_receipt["amountOut"].to_s)
    unless valid_transaction?(transaction_receipt, amount_in, amount_out)
      update_trade(trade, amount_in, amount_out, token_pair.current_price, transaction_receipt, :failed)
      return :failed
    end

    trade_price = amount_out / amount_in

    update_trade(trade, amount_in, amount_out, trade_price, transaction_receipt)
    
    trade.reload

    trade.bot.process_trade(trade)
    return :completed
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
      gas_used: transaction_receipt["gasUsedWei"],
      transaction_fee_wei: transaction_receipt["transactionFeeWei"],
      confirmed_at: Time.current
    )
  end
end
