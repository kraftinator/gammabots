class CreateBots < ActiveRecord::Migration[7.2]
  def change
    create_table :bots do |t|
      t.references :chain, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :token_pair, null: false, foreign_key: true

      t.decimal :initial_base_token_amount, precision: 30, scale: 10, null: false, default: 0
      t.decimal :base_token_amount, precision: 30, scale: 10, null: false, default: 0
      t.decimal :quote_token_amount, precision: 30, scale: 10, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.datetime :last_traded_at

      t.timestamps
    end

    add_index :bots, :last_traded_at
  end
end
