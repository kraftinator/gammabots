class CreateFeeCollections < ActiveRecord::Migration[7.2]
  def change
    create_table :fee_collections do |t|
      t.references :trade, null: false, foreign_key: true

      # WETH amount collected from the trade
      t.decimal  :amount, precision: 30, scale: 18, null: false

      # bot → router collection
      t.string   :status, null: false, default: "pending"   # pending, collected, failed
      t.string   :tx_hash
      t.datetime :collected_at

      # unwrap tracking (WETH to ETH)
      t.string   :unwrap_status, null: false, default: "pending" # pending, unwrapped, failed
      t.string   :unwrap_tx_hash
      t.datetime :unwrapped_at

      t.timestamps
    end
  end
end
