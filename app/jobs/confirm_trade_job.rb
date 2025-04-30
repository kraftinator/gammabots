class ConfirmTradeJob < ApplicationJob
  def perform(trade_id)
    trade = Trade.find_by(id: trade_id)
    return unless trade&.pending?

    provider_url = ProviderUrlService.get_provider_url(trade.bot.chain.name)
    TradeConfirmationService.confirm_trade(trade, provider_url)

    # if still pending, re‑enqueue in 30 seconds
    if trade.reload.pending?
      ConfirmTradeJob.set(wait: 30.seconds).perform_later(trade.id)
    end
  end
end
