class AddWethUnwrappedAmountToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :weth_unwrapped_amount, :decimal, precision: 30, scale: 18
  end
end
