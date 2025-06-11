class AddProfitFieldsToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :profit_share,     :decimal, precision: 5, scale: 4, null: false, default: "0.50"
    add_column :bots, :profit_threshold, :decimal, precision: 5, scale: 4, null: false, default: "0.10"
  end
end
