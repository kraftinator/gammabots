class BotRunner
  extend BotLock

  def self.run(bot_or_id)
    bot_id =
      case bot_or_id
      when Bot
        bot_or_id.id
      else
        bot_or_id
      end

    locked = with_bot_lock(bot_id) do
      bot = Bot.find_by(id: bot_id)
      if (latest = bot.latest_trade)&.pending?
        Rails.logger.info "Skipping Bot #{bot.id}: trade ##{latest.id} still pending"
        return
      end

      return unless bot.can_run?
      return unless bot.token_pair
      #return unless bot.active? && bot.token_pair

      strategy = TradingStrategy.new(bot, bot.provider_url)
      strategy.process
    end
    Rails.logger.info "Skipping Bot #{bot_id}: lock held by another job" unless locked
  end
end
