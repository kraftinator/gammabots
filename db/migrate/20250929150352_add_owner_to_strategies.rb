class AddOwnerToStrategies < ActiveRecord::Migration[7.2]
  def change
    add_column :strategies, :owner_address, :string
    add_column :strategies, :owner_refreshed_at, :datetime

    add_index :strategies, :owner_address
  end
end
