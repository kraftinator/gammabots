class AddWethWrapFieldsToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :weth_wrap_tx_hash, :string
    add_column :bots, :weth_wrapped_at,   :datetime

    add_index  :bots, :weth_wrap_tx_hash, unique: true
  end
end
