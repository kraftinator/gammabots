class AddStatusToStrategies < ActiveRecord::Migration[7.2]
  def change
    add_column :strategies, :status, :string, default: "active", null: false
    add_index  :strategies, :status
  end
end