class RemovePreviousPriceFromTokenPairs < ActiveRecord::Migration[7.2]
  def change
    remove_column :token_pairs,
                  :previous_price,
                  :decimal,
                  precision: 30,
                  scale: 18
  end
end
