class CreateTokenPairPrices < ActiveRecord::Migration[7.2]
  def change
    create_table :token_pair_prices do |t|
      t.references :token_pair, null: false, foreign_key: true
      t.decimal :price, precision: 30, scale: 18, null: false

      t.timestamps null: false
    end

    add_index :token_pair_prices, [:token_pair_id, :created_at], name: "index_token_pair_prices_on_token_pair_id_and_created_at"
  end
end
