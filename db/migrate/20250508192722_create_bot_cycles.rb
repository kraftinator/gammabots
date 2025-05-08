class CreateBotCycles < ActiveRecord::Migration[7.2]
  def change
    create_table :bot_cycles do |t|
      t.references :bot, null: false, foreign_key: true, index: true

      # Amounts tracked per cycle (copied from bots table)
      t.decimal :initial_buy_amount, precision: 30, scale: 18, default: "0.0", null: false
      t.decimal :base_token_amount, precision: 30, scale: 18, default: "0.0", null: false
      t.decimal :quote_token_amount, precision: 30, scale: 18, default: "0.0", null: false

      # Price metrics (from bots table)
      t.decimal :initial_buy_price, precision: 30, scale: 18
      t.decimal :highest_price_since_initial_buy, precision: 30, scale: 18
      t.decimal :lowest_price_since_initial_buy, precision: 30, scale: 18
      t.decimal :highest_price_since_last_trade, precision: 30, scale: 18
      t.decimal :lowest_price_since_last_trade, precision: 30, scale: 18
      t.decimal :lowest_price_since_creation, precision: 30, scale: 18
      t.decimal :created_at_price, precision: 30, scale: 18

      # Moving-average metrics (from bots table)
      t.decimal :lowest_moving_avg_since_creation, precision: 30, scale: 18
      t.decimal :highest_moving_avg_since_initial_buy, precision: 30, scale: 18
      t.decimal :lowest_moving_avg_since_initial_buy, precision: 30, scale: 18
      t.decimal :highest_moving_avg_since_last_trade, precision: 30, scale: 18
      t.decimal :lowest_moving_avg_since_last_trade, precision: 30, scale: 18

      # Cycle boundaries
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    # For quick lookup of the active cycle
    add_index :bot_cycles, [:bot_id, :ended_at]
  end
end
