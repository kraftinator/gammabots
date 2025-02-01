class RenamePriceColumnsInBots < ActiveRecord::Migration[7.2]
  def change
    rename_column :bots, :highest_price_since_buy, :highest_price_since_initial_buy
    rename_column :bots, :lowest_price_since_buy, :lowest_price_since_initial_buy
  end
end
