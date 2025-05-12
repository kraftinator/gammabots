class AddResetRequestedAtToBotCycles < ActiveRecord::Migration[7.2]
  def change
    add_column :bot_cycles, :reset_requested_at, :datetime, null: true
    add_index  :bot_cycles, :reset_requested_at
  end
end
