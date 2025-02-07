class BotRunnerJob
  include Sidekiq::Job

  def perform(bot_id)
    bot = Bot.find_by(id: bot_id)
    BotRunner.run(bot)
  end
end
