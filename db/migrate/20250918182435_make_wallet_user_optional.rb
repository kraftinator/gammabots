class MakeWalletUserOptional < ActiveRecord::Migration[7.2]
  def change
    change_column_null :wallets, :user_id, true
  end
end
