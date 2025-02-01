class RemoveTotalValueFromTrades < ActiveRecord::Migration[7.2]
  def change
    remove_column :trades, :total_value
  end
end
