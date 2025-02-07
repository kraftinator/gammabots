class CreateStrategies < ActiveRecord::Migration[7.2]
  def change
    create_table :strategies do |t|
      t.references :chain, null: false, foreign_key: true
      t.string :contract_address, null: false
      t.string :nft_token_id,     null: false
      t.text :strategy_json,      null: false

      t.timestamps
    end

    add_index :strategies, [:contract_address, :nft_token_id], unique: true
  end
end
