class AddCopyBotFieldsToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :bot_type, :string, default: 'default', null: false
    add_column :bots, :copy_wallet_address, :string
    
    # Make token_pair_id nullable since copy bots don't have one initially
    change_column_null :bots, :token_pair_id, true
    
    # Add indexes for efficient queries
    add_index :bots, :bot_type
    add_index :bots, :copy_wallet_address
    add_index :bots, [:bot_type, :copy_wallet_address, :token_pair_id], name: 'index_bots_on_copy_bot_fields'
  end
end
