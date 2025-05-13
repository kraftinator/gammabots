class AddNonceToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :nonce, :bigint
    
    add_index :trades, :nonce
  end
end
