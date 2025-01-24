class CreateTokens < ActiveRecord::Migration[7.2]
  def change
    create_table :tokens do |t|
      t.references :chain, null: false, foreign_key: true
      t.string :symbol, null: false
      t.string :name, null: false
      t.string :contract_address, null: false
      t.integer :decimals, null: false, default: 18

      t.timestamps
    end

    add_index :tokens, [:chain_id, :symbol], unique: true
    add_index :tokens, [:chain_id, :contract_address], unique: true
  end
end
