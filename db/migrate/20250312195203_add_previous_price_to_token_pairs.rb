class AddPreviousPriceToTokenPairs < ActiveRecord::Migration[7.2]
  def change
    add_column :token_pairs, :previous_price, :decimal, precision: 30, scale: 18
  end
end
