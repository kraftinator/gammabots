class CreateChains < ActiveRecord::Migration[7.2]
  def change
    create_table :chains do |t|
      t.string :name, null: false
      t.string :native_chain_id, null: false
      t.string :rpc_url
      t.string :explorer_url

      t.timestamps
    end

    add_index :chains, :name, unique: true
    add_index :chains, :native_chain_id, unique: true
  end
end
