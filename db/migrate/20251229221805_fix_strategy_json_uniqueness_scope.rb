class FixStrategyJsonUniquenessScope < ActiveRecord::Migration[7.2]
  def change
    # Remove the old global uniqueness constraint
    remove_index :strategies, name: "index_strategies_on_strategy_json"

    # Enforce uniqueness per chain + contract (only once the mint has populated these)
    add_index :strategies,
              [:chain_id, :contract_address, :strategy_json],
              unique: true,
              name: "index_strategies_on_chain_contract_and_strategy_json",
              where: "contract_address IS NOT NULL AND strategy_json IS NOT NULL"
  end
end
