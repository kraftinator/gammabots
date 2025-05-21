class AddMetricsToTrades < ActiveRecord::Migration[7.2]
  def change
    add_column :trades, :metrics, :jsonb, default: {}
  end
end
