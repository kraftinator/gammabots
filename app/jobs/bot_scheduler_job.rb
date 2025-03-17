class BotSchedulerJob
  include Sidekiq::Job

  def perform
    bots_by_token_pair = Bot.active.group_by(&:token_pair_id)

    bots_by_token_pair.each do |token_pair_id, bots|
      next unless token_pair_id

      token_pair = TokenPair.find(token_pair_id)
      token_pair.latest_price

      bots.each do |bot|
        BotRunnerJob.perform_async(bot.id)
      end
    end
  end
end
