class StartFirstCycleJob < ApplicationJob
  RETRY_DELAY = 30.seconds
  MAX_TRIES   = 10

  def perform(bot_id, attempts = 1)
    bot = Bot.find_by(id: bot_id)
    return unless bot&.status == 'active'

    BotCycleSeeder.seed!(bot)
    bot.update!(active: true)
  rescue => e
    if attempts < MAX_TRIES
      Rails.logger.warn "[StartFirstCycleJob] #{e.class}: #{e.message}; retrying (#{attempts}/#{MAX_TRIES})"
      self.class.set(wait: RETRY_DELAY).perform_later(bot_id, attempts + 1)
    else
      Rails.logger.error "[StartFirstCycleJob] Giving up for Bot##{bot_id}"
      # optional: mark a status like 'cycle_seed_failed' or notify ops
    end
  end
end