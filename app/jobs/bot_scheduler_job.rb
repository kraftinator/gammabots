class BotSchedulerJob
  include Sidekiq::Job

  def perform
    bots_by_token_pair = Bot.active.includes(token_pair: [:base_token, :quote_token]).group_by(&:token_pair_id)

    bots_by_token_pair.each do |token_pair_id, bots|
      next unless token_pair_id

      token_pair = bots.first&.token_pair
      next unless token_pair
      token_pair.latest_price

      bots.each do |bot|
        BotRunnerJob.perform_async(bot.id)
      end
    end
  end
end
