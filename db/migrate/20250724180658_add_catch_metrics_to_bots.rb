class AddCatchMetricsToBots < ActiveRecord::Migration[7.2]
  def change
    add_column :bots, :catch_metrics, :boolean, null: false, default: false
  end
end