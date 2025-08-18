class CreateDashboardMetrics < ActiveRecord::Migration[7.2]
  def change
    create_table :dashboard_metrics do |t|
      t.integer :active_bots, null: false, default: 0
      t.bigint  :tvl_cents, null: false, default: 0
      t.bigint  :volume_24h_cents, null: false, default: 0
      t.integer :strategies_count, null: false, default: 0
      t.bigint  :total_profits_cents, null: false, default: 0
      t.integer :win_rate_bps, null: false, default: 0   # e.g. 7325 = 73.25%

      t.timestamps  # gives created_at, updated_at
    end

    add_index :dashboard_metrics, :created_at
  end
end
