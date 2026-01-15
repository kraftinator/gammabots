class AddFeedsToDashboardMetrics < ActiveRecord::Migration[7.2]
  def change
    add_column :dashboard_metrics, :popular_tokens_json, :jsonb, null: false, default: []
    add_column :dashboard_metrics, :recent_activity_json, :jsonb, null: false, default: []
    add_column :dashboard_metrics, :top_performers_json, :jsonb, null: false, default: []
  end
end
