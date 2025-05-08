namespace :db do
  desc "Populate bot_cycles table from existing bots and link trades"
  task populate_bot_cycles: :environment do
    puts "Starting to migrate bots into bot_cycles..."

    Bot.find_each(batch_size: 100) do |bot|
      cycle = BotCycle.create!(
        bot: bot,
        # Amounts copied from bots table
        initial_buy_amount:              bot.initial_buy_amount,
        base_token_amount:               bot.base_token_amount,
        quote_token_amount:              bot.quote_token_amount,
        # Price metrics copied from bots table
        initial_buy_price:               bot.initial_buy_price,
        highest_price_since_initial_buy: bot.highest_price_since_initial_buy,
        lowest_price_since_initial_buy:  bot.lowest_price_since_initial_buy,
        highest_price_since_last_trade:  bot.highest_price_since_last_trade,
        lowest_price_since_last_trade:   bot.lowest_price_since_last_trade,
        lowest_price_since_creation:     bot.lowest_price_since_creation,
        created_at_price:                bot.created_at_price,
        # Moving-average metrics copied from bots table
        lowest_moving_avg_since_creation:     bot.lowest_moving_avg_since_creation,
        highest_moving_avg_since_initial_buy: bot.highest_moving_avg_since_initial_buy,
        lowest_moving_avg_since_initial_buy:  bot.lowest_moving_avg_since_initial_buy,
        highest_moving_avg_since_last_trade:  bot.highest_moving_avg_since_last_trade,
        lowest_moving_avg_since_last_trade:   bot.lowest_moving_avg_since_last_trade,
        # Cycle boundaries
        started_at: bot.created_at,
        ended_at:   (bot.active? ? nil : bot.updated_at)
      )

      # Link all existing trades to this new cycle
      bot.trades.update_all(bot_cycle_id: cycle.id)
    end

    puts "Finished populating bot_cycles and linking trades."
  end
end
