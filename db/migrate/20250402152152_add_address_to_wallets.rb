class AddAddressToWallets < ActiveRecord::Migration[7.2]
  def change
    add_column :wallets, :address, :string
    
    add_index :wallets, :address, unique: true
  end
end
