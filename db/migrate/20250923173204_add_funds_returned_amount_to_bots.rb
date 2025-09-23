class AddFundsReturnedAmountToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :funds_returned_amount, :decimal, precision: 30, scale: 18, default: "0.0", null: false
  end
end
