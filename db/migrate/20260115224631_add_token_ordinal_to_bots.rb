class AddTokenOrdinalToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :token_ordinal, :integer
    add_index  :bots, [:token_pair_id, :token_ordinal], unique: true
  end
end
