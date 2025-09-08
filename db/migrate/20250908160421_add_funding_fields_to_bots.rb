class AddFundingFieldsToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :funding_tx_hash, :string
    add_column :bots, :funding_confirmed_at, :datetime
    add_column :bots, :funder_address, :string

    add_index :bots, :funding_tx_hash, unique: true, name: "index_bots_on_funding_tx_hash"
    add_index :bots, :funder_address, name: "index_bots_on_funder_address"
  end
end
