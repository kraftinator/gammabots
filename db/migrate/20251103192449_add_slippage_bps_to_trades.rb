class AddSlippageBpsToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :max_slippage_bps, :integer
  end
end
