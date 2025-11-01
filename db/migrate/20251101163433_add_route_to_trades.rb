class AddRouteToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :route, :jsonb
  end
end
