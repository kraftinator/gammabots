class AddMintFieldsToStrategies < ActiveRecord::Migration[7.2]
  def change
    add_column :strategies, :mint_tx_hash, :string, null: true
    add_column :strategies, :mint_status, :string, null: false, default: "pending"

    add_index :strategies, :mint_tx_hash, unique: true

    change_column_null :strategies, :nft_token_id, true
    change_column_null :strategies, :strategy_json, true
    change_column_null :strategies, :owner_address, true
  end
end
