class AddTransactionFeeWeiToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :transaction_fee_wei, :decimal, precision: 30, scale: 0
  end
end
