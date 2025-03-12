class AddCreatedAtPriceToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :created_at_price, :decimal, precision: 30, scale: 18
  end
end
