class ConfirmTradeJob < ApplicationJob
  MAX_ATTEMPTS = 5

  def perform(trade_id, attempt = 1)
    trade = Trade.find_by(id: trade_id)
    return unless trade&.pending?

    provider_url = ProviderUrlService.get_provider_url(trade.bot.chain.name)
    TradeConfirmationService.confirm_trade(trade, provider_url)
    trade.reload

    case trade.status
    when "pending"
      if attempt < MAX_ATTEMPTS
        # if still pending, re‑enqueue in 30 seconds
        self.class.set(wait: 30.seconds).perform_later(trade.id, attempt + 1)
      else
        Rails.logger.info "[ConfirmTradeJob] Trade##{trade.id} confirmation failed after #{MAX_ATTEMPTS} attempts"
        # if still pending after max attempts, update to failed
        trade.update!(status: :failed)
        handle_failed_sell(trade.reload) if trade.sell?
      end
    when "failed"
      # if failed liquidation, update bot to active
      handle_failed_sell(trade) if trade.sell?
    end
  end

  private

  def handle_failed_sell(trade)
    bot = trade.bot.reload
    return if bot.active?

    Rails.logger.info "[ConfirmTradeJob] reactivating Bot##{bot.id} after failed sell Trade##{trade.id}"
    bot.update!(active: true)
  end
end
