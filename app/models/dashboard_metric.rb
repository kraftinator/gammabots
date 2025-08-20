# app/models/dashboard_metric.rb
class DashboardMetric < ApplicationRecord
  # --- Validations ---
  validates :active_bots, :tvl_cents, :volume_24h_cents,
            :strategies_count, :trades_executed, :total_profits_cents, presence: true
            
  validates :active_bots, :strategies_count, :trades_executed, numericality: { greater_than_or_equal_to: 0 }
  validates :tvl_cents, :volume_24h_cents, :total_profits_cents, 
            numericality: { greater_than_or_equal_to: 0 }

  # --- Scopes ---
  scope :latest, -> { order(created_at: :desc).first }
  scope :previous, -> { order(created_at: :desc).offset(1).first }
  scope :from_24_hours_ago, -> { where(created_at: 24.hours.ago..23.hours.ago).order(created_at: :desc).first }

  # --- Callbacks ---
  after_create :cleanup_old_records

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

  private

  def cleanup_old_records
    # Keep records for 48 hours (every 5 min = 12 per hour = 288 per day = 576 for 48 hours)
    # This ensures we always have 24h comparison data plus some buffer
    self.class.order(created_at: :desc).offset(600).destroy_all
  end
end