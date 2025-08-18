# app/models/dashboard_metric.rb
class DashboardMetric < ApplicationRecord
  # --- Validations ---
  validates :active_bots, :tvl_cents, :volume_24h_cents,
            :strategies_count, :total_profits_cents,
            :win_rate_bps, presence: true

  # --- Scopes ---
  scope :latest, -> { order(created_at: :desc).first }
  scope :previous, -> { order(created_at: :desc).offset(1).first }

  # --- Helpers ---

  # Convert cents → dollars
  def tvl_usd
    tvl_cents.to_f / 100.0
  end

  def volume_24h_usd
    volume_24h_cents.to_f / 100.0
  end

  def total_profits_usd
    total_profits_cents.to_f / 100.0
  end

  # Convert basis points → percentage
  def win_rate_percent
    win_rate_bps.to_f / 100.0
  end
end