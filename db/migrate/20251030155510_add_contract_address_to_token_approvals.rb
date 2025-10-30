class AddContractAddressToTokenApprovals < ActiveRecord::Migration[7.2]
  def up
    add_column :token_approvals, :contract_address, :string

    # Replace the old unique index (wallet_id, token_id) with a new one that includes contract_address
    remove_index :token_approvals,
                 name: "index_token_approvals_on_wallet_id_and_token_id",
                 if_exists: true

    add_index :token_approvals,
              [:wallet_id, :token_id, :contract_address],
              unique: true,
              name: "index_token_approvals_on_wallet_token_contract"
  end

  def down
    remove_index :token_approvals,
                 name: "index_token_approvals_on_wallet_token_contract",
                 if_exists: true

    add_index :token_approvals,
              [:wallet_id, :token_id],
              unique: true,
              name: "index_token_approvals_on_wallet_id_and_token_id"

    remove_column :token_approvals, :contract_address
  end
end
