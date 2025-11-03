class BotRunner
  extend BotLock

  def self.run(bot)
    locked = with_bot_lock(bot.id) do
      if (latest = bot.latest_trade)&.pending?
        Rails.logger.info "Skipping Bot #{bot.id}: trade ##{latest.id} still pending"
        return
      end

      return unless bot.active? && bot.token_pair

      strategy = TradingStrategy.new(bot, bot.provider_url)
      strategy.process
    end
    Rails.logger.info "Skipping Bot #{bot.id}: lock held by another job" unless locked
  end
end
