class CreatePendingCopyTrades < ActiveRecord::Migration[7.2]
  def change
    create_table :pending_copy_trades do |t|
      t.string :wallet_address, null: false
      t.string :token_address, null: false
      t.decimal :amount_out, precision: 30, scale: 18, null: false
      t.string :tx_hash, null: false
      t.bigint :block_number, null: false
      t.string :status, default: 'pending'
      
      t.timestamps
    end

    add_index :pending_copy_trades, :tx_hash, unique: true
    add_index :pending_copy_trades, :status
    add_index :pending_copy_trades, :token_address
    add_index :pending_copy_trades, [:status, :created_at]
  end
end
