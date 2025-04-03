class RenameMovingAverageColumns < ActiveRecord::Migration[7.2]
  def change
    rename_column :bots, :lowest_moving_average_since_creation, :lowest_moving_avg_since_creation
    rename_column :bots, :highest_moving_average_since_initial_buy, :highest_moving_avg_since_initial_buy
    rename_column :bots, :lowest_moving_average_since_initial_buy, :lowest_moving_avg_since_initial_buy
    rename_column :bots, :highest_moving_average_since_last_trade, :highest_moving_avg_since_last_trade
    rename_column :bots, :lowest_moving_average_since_last_trade, :lowest_moving_avg_since_last_trade
  end
end
