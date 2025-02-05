class BotRunner
  def self.run(bot)
    provider_url = ProviderUrlService.get_provider_url(bot.chain.name)
    
    latest_trade = bot.latest_trade
    if latest_trade&.pending?
      puts "Bot #{bot.id} has a pending trade. Checking transaction receipt..."
      TradeConfirmationService.confirm_trade(latest_trade, provider_url)
      latest_trade.reload
      return if latest_trade.pending? # If still pending, skip this run
    end

    return unless bot.active?

    strategy = TradingStrategy.new(bot, provider_url)
    strategy.process
  end
end
