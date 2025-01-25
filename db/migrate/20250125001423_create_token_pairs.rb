class CreateTokenPairs < ActiveRecord::Migration[7.2]
  def change
    create_table :token_pairs do |t|
      t.references :chain, null: false, foreign_key: true
      t.references :base_token, null: false, foreign_key: { to_table: :tokens }
      t.references :quote_token, null: false, foreign_key: { to_table: :tokens }

      t.timestamps
    end

    add_index :token_pairs, [:chain_id, :base_token_id, :quote_token_id], unique: true
  end
end
