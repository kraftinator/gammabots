class ConfirmTradeJob < ApplicationJob
  def perform(trade_id)
    trade = Trade.find_by(id: trade_id)
    return unless trade&.pending?

    provider_url = ProviderUrlService.get_provider_url(trade.bot.chain.name)
    TradeConfirmationService.confirm_trade(trade, provider_url)
    trade.reload

    case trade.status
    when "pending"
      # if still pending, re‑enqueue in 30 seconds
      self.class.set(wait: 30.seconds).perform_later(trade.id)
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
