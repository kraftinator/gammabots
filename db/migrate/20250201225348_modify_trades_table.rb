class ModifyTradesTable < ActiveRecord::Migration[7.2]
  def change
    change_column :trades, :price, :decimal, precision: 30, scale: 18
    change_column :trades, :amount, :decimal, precision: 30, scale: 18
    change_column :trades, :total_value, :decimal, precision: 30, scale: 18
    change_column :trades, :gas_used, :decimal, precision: 30, scale: 0
    change_column_null :trades, :tx_hash, false
    change_column_default :trades, :status, "pending"
  end
end
