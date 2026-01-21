class AddDeactivationRequestedAtToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :deactivation_requested_at, :datetime
    add_index  :bots, :deactivation_requested_at
  end
end
