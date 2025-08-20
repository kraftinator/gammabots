class UpdateDashboardMetricsReplaceWinRateWithTrades < ActiveRecord::Migration[7.2]
  def change
    remove_column :dashboard_metrics, :win_rate_bps, :integer, default: 0, null: false
    add_column :dashboard_metrics, :trades_executed, :bigint, default: 0, null: false
  end
end