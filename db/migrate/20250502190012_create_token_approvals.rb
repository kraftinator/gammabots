class CreateTokenApprovals < ActiveRecord::Migration[7.2]
  def change
    create_table :token_approvals do |t|
      t.references :wallet, null: false, foreign_key: true, index: true
      t.references :token, null: false, foreign_key: true, index: true
      t.string     :status, null: false, default: 'pending'  # pending | confirmed | failed
      t.string     :tx_hash
      t.datetime   :confirmed_at
      t.timestamps
    end

    add_index :token_approvals, [:wallet_id, :token_id], unique: true
  end
end
