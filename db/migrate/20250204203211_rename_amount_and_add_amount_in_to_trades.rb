class RenameAmountAndAddAmountInToTrades < ActiveRecord::Migration[7.2]
  def change
    rename_column :trades, :amount, :amount_out
    add_column :trades, :amount_in, :decimal, precision: 30, scale: 18
  end
end
