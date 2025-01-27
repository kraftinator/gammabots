class CreateTrades < ActiveRecord::Migration[7.2]
  def change
    create_table :trades do |t|
      t.references :bot, null: false, foreign_key: true
      t.string :trade_type, null: false # Buy or Sell
      t.decimal :price, precision: 18, scale: 8, null: false
      t.decimal :amount, precision: 18, scale: 8, null: false
      t.decimal :total_value, precision: 18, scale: 8, null: false
      t.datetime :executed_at, null: false
      t.string :tx_hash
      t.string :status, default: "completed"

      t.timestamps
    end

    # Indexes
    add_index :trades, :trade_type
    add_index :trades, :executed_at
    add_index :trades, :tx_hash, unique: true
  end
end
