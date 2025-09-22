class AddReturnFundsTrackingToBots < ActiveRecord::Migration[7.2]
  def change
    change_table :bots, bulk: true do |t|
      # Track WETH to ETH unwrap
      t.string   :weth_unwrap_tx_hash
      t.string   :weth_unwrap_status        # null until deactivation kicks off
      t.datetime :weth_unwrapped_at

      # Track ETH return to user
      t.string   :funds_return_tx_hash
      t.string   :funds_return_status       # null until return funds job kicks off
      t.datetime :funds_returned_at
    end

    add_index :bots, :weth_unwrap_tx_hash
    add_index :bots, :funds_return_tx_hash
  end
end
