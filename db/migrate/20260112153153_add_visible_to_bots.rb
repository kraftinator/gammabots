class AddVisibleToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :visible, :boolean, null: false, default: true
    add_index  :bots, :visible
  end
end
