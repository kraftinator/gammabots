class AllowNullValuesForPendingTrades < ActiveRecord::Migration[7.2]
  def change
    change_column_null :trades, :price, true
    change_column_null :trades, :amount, true
    change_column_null :trades, :total_value, true
  end
end
