class AddHighestPriceSinceCreationToBotCycles < ActiveRecord::Migration[7.2]
  def change
    add_column :bot_cycles, :highest_price_since_creation, :decimal, precision: 30, scale: 18
  end
end
