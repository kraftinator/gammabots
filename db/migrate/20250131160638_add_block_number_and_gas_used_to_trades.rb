class AddBlockNumberAndGasUsedToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :block_number, :bigint
    add_column :trades, :gas_used, :decimal, precision: 30, scale: 0

    add_index :trades, :block_number
  end
end
