class AddMovingAverageFieldsToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :lowest_moving_average_since_creation, :decimal, precision: 30, scale: 18
    add_column :bots, :highest_moving_average_since_initial_buy, :decimal, precision: 30, scale: 18
    add_column :bots, :lowest_moving_average_since_initial_buy, :decimal, precision: 30, scale: 18
    add_column :bots, :highest_moving_average_since_last_trade, :decimal, precision: 30, scale: 18
    add_column :bots, :lowest_moving_average_since_last_trade, :decimal, precision: 30, scale: 18
  end
end
