class RemoveUrlFromChains < ActiveRecord::Migration[7.2]
  def change
    remove_column :chains, :rpc_url, :string
  end
end
