class BotRunner
  def self.run(bot)
    if (latest = bot.latest_trade)&.pending?
      Rails.logger.info "Skipping Bot #{bot.id}: trade ##{latest.id} still pending"
      return
    end

    return unless bot.active?

    strategy = TradingStrategy.new(bot, bot.provider_url)
    strategy.process
  end
end
