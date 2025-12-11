class AddLiquidatedAtToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :liquidated_at, :datetime
  end
end
