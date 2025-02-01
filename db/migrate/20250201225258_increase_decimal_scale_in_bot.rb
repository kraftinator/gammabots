class IncreaseDecimalScaleInBot < ActiveRecord::Migration[7.2]
  def change
    change_column :bots, :initial_buy_amount, :decimal, precision: 30, scale: 18
    change_column :bots, :base_token_amount, :decimal, precision: 30, scale: 18
    change_column :bots, :quote_token_amount, :decimal, precision: 30, scale: 18
  end
end
