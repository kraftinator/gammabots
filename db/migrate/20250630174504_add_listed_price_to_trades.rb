class AddListedPriceToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :listed_price, :decimal, precision: 30, scale: 18
  end
end
