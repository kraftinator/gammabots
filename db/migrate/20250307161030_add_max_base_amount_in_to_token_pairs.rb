class AddMaxBaseAmountInToTokenPairs < ActiveRecord::Migration[7.2]
  def change
    add_column :token_pairs, :max_base_amount_in, :decimal, precision: 30, scale: 18
  end
end
