class AddDeactivatedAtToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :deactivated_at, :datetime
    add_index  :bots, :deactivated_at
  end
end
