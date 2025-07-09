class RemoveUniqueConstraintOnSymbol < ActiveRecord::Migration[7.2]
  def change
    # Remove the existing unique index on chain_id and symbol
    remove_index :tokens, name: "index_tokens_on_chain_id_and_symbol"
    
    # Add a new non-unique index on chain_id and symbol
    add_index :tokens, [:chain_id, :symbol], name: "index_tokens_on_chain_id_and_symbol"
  end
end
