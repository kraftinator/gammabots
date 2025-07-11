class CreateCopyTrades < ActiveRecord::Migration[7.2]
  def change
    create_table :copy_trades do |t|
      t.string :wallet_address, null: false
      t.string :tx_hash, null: false
      t.bigint :block_number, null: false
      t.references :token_pair, null: false, foreign_key: true  # This already creates an index
      t.decimal :amount_out, precision: 30, scale: 18, null: false
      t.decimal :amount_in, precision: 30, scale: 18
      
      t.timestamps
    end

    add_index :copy_trades, :tx_hash, unique: true
    add_index :copy_trades, :wallet_address
    add_index :copy_trades, [:wallet_address, :created_at]
    add_index :copy_trades, :block_number
  end
end
