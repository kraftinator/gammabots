class RemoveUnusedMetricsFromBots < ActiveRecord::Migration[7.2]
  def change
    remove_column :bots, :base_token_amount
    remove_column :bots, :quote_token_amount
    remove_column :bots, :last_traded_at
    remove_column :bots, :initial_buy_price
    remove_column :bots, :highest_price_since_initial_buy
    remove_column :bots, :lowest_price_since_initial_buy
    remove_column :bots, :highest_price_since_last_trade
    remove_column :bots, :lowest_price_since_last_trade
    remove_column :bots, :lowest_price_since_creation
    remove_column :bots, :created_at_price
    remove_column :bots, :lowest_moving_avg_since_creation
    remove_column :bots, :highest_moving_avg_since_initial_buy
    remove_column :bots, :lowest_moving_avg_since_initial_buy
    remove_column :bots, :highest_moving_avg_since_last_trade
    remove_column :bots, :lowest_moving_avg_since_last_trade
  end
end
