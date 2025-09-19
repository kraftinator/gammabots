class RemoveFeeFieldsFromTrades < ActiveRecord::Migration[7.2]
  def change
    remove_column :trades, :fee_amount, :decimal, precision: 30, scale: 18, default: "0.0", null: false
    remove_column :trades, :fee_collected, :boolean, default: false, null: false
    remove_column :trades, :fee_collected_at, :datetime
    remove_column :trades, :fee_collection_tx_hash, :string
  end
end
