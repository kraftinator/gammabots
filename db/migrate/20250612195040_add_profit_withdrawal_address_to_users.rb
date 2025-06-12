class AddProfitWithdrawalAddressToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :profit_withdrawal_address, :string
  end
end
