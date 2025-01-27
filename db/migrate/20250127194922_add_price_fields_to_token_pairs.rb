class AddPriceFieldsToTokenPairs < ActiveRecord::Migration[7.2]
  def change
    add_column :token_pairs, :current_price, :decimal, precision: 30, scale: 18, null: true
    add_column :token_pairs, :price_updated_at, :datetime, null: true
  end
end
