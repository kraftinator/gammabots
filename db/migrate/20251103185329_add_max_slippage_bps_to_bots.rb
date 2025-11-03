class AddMaxSlippageBpsToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :max_slippage_bps, :integer, null: false, default: 200
    add_index  :bots, :max_slippage_bps
  end
end
