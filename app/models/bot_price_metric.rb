# app/models/bot_price_metric.rb
class BotPriceMetric < ApplicationRecord
  belongs_to :bot

  # Ensure we always have the price and a metrics hash
  validates :price, presence: true, numericality: true
  validates :metrics, presence: true

  # Make it easy to work with keys without string/symbol confusion
  def metrics
    super.with_indifferent_access
  end
end