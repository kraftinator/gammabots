class CreateWallets < ActiveRecord::Migration[7.2]
  def change
    create_table :wallets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chain, null: false, foreign_key: true
      t.string :private_key, null: false

      t.timestamps
    end

    add_index :wallets, [:user_id, :chain_id], unique: true
  end
end
