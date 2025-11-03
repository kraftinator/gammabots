class AddFieldsToProfitWithdrawals < ActiveRecord::Migration[7.2]
  def change
    add_column :profit_withdrawals, :gas_used, :decimal, precision: 30
    add_column :profit_withdrawals, :block_number, :bigint
    add_column :profit_withdrawals, :transaction_fee_wei, :decimal, precision: 30
    add_column :profit_withdrawals, :route, :jsonb
  end
end
