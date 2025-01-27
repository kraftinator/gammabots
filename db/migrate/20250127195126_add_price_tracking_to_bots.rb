class AddPriceTrackingToBots < ActiveRecord::Migration[7.2]
  def change
    rename_column :bots, :initial_base_token_amount, :initial_buy_amount

    change_table :bots, bulk: true do |t|
      t.decimal :initial_buy_price, precision: 30, scale: 18, null: true
      t.decimal :highest_price_since_buy, precision: 30, scale: 18, null: true
      t.decimal :lowest_price_since_buy, precision: 30, scale: 18, null: true
      t.decimal :highest_price_since_last_trade, precision: 30, scale: 18, null: true
      t.decimal :lowest_price_since_last_trade, precision: 30, scale: 18, null: true
    end
  end
end
