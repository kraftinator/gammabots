class ConfirmTradeJob < ApplicationJob
  MAX_ATTEMPTS = 5

  def perform(trade_id, attempt = 1)
    trade = Trade.find_by(id: trade_id)
    return unless trade&.pending?

    provider_url = ProviderUrlService.get_provider_url(trade.bot.chain.name)

    result = TradeConfirmationService.confirm_trade(trade, provider_url)
    trade.reload
    return if trade.completed?

    case result
    when :completed, :not_pending
      return

    when :failed
      handle_failed_sell(trade) if trade.sell?
      return

    when :not_found
      # retry slower
      wait = [5.minutes * attempt, 30.minutes].min
      self.class.set(wait: wait).perform_later(trade.id, attempt + 1)
      return

    when :pending, :temporary_error
      # normal retry
      if attempt < MAX_ATTEMPTS
        self.class.set(wait: 30.seconds).perform_later(trade.id, attempt + 1)
      else
        # IMPORTANT: do NOT mark failed just because it's still pending
        self.class.set(wait: 10.minutes).perform_later(trade.id, attempt + 1)
      end
      return

    else
      Rails.logger.warn "[ConfirmTradeJob] Unexpected result=#{result.inspect} for Trade##{trade.id}; retrying"
      self.class.set(wait: 2.minutes).perform_later(trade.id, attempt + 1)
      return
    end
  end

  private

  def handle_failed_sell(trade)
    bot = trade.bot.reload
    return if bot.active?

    Rails.logger.info "[ConfirmTradeJob] reactivating Bot##{bot.id} after failed sell Trade##{trade.id}"
    #bot.update!(active: true)

    bot.update!(
      status: "active",
      active: true,
      deactivation_requested_at: nil
    )
  end
end