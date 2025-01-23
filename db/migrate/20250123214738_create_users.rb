class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :farcaster_id, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :users, :farcaster_id, unique: true
  end
end
