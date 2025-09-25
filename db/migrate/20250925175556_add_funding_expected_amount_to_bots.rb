class AddFundingExpectedAmountToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :funding_expected_amount, :decimal, precision: 30, scale: 18
  end
end
