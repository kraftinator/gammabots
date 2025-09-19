class AddKindToWallets < ActiveRecord::Migration[7.2]
  def change
    add_column :wallets, :kind, :string, null: false, default: "user"
  end
end
