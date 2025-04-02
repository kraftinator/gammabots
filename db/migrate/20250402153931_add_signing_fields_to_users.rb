class AddSigningFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :created_by_signature, :string
    add_column :users, :created_by_wallet, :string
  end
end
