class AddFeeCollectionToTrades < ActiveRecord::Migration[7.2]
  def change
    change_table :trades do |t|
      # exact fee amount (in WETH)
      t.decimal :fee_amount, precision: 30, scale: 18, default: "0.0", null: false

      # did we successfully transfer fee to router?
      t.boolean  :fee_collected, default: false, null: false

      # when the transfer was confirmed
      t.datetime :fee_collected_at

      # tx hash of the bot → router transfer (for audit/debugging)
      t.string   :fee_collection_tx_hash
    end
  end
end
