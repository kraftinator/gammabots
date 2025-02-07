class BotSchedulerJob
  include Sidekiq::Job

  def perform
    Bot.active.each do |bot|
    #Bot.all.each do |bot|
      BotRunnerJob.perform_async(bot.id)
    end
  end
end
