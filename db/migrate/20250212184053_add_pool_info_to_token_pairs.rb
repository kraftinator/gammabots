class AddPoolInfoToTokenPairs < ActiveRecord::Migration[7.2]
  def change
    add_column :token_pairs, :pool_address, :string
    add_column :token_pairs, :fee_tier, :integer
    add_column :token_pairs, :pool_address_updated_at, :datetime

    add_index :token_pairs, :pool_address
  end
end
