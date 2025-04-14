class TokenPair < ApplicationRecord
  belongs_to :chain
  belongs_to :base_token, class_name: "Token"
  belongs_to :quote_token, class_name: "Token"
  has_many :bots, dependent: :destroy
  has_many :token_pair_prices, dependent: :destroy

  validates :base_token, presence: true
  validates :quote_token, presence: true
  validates :chain, presence: true
  validate :tokens_cannot_be_same

  # Validation
  def tokens_cannot_be_same
    if base_token_id == quote_token_id
      errors.add(:quote_token, "cannot be the same as base token")
    end
  end

  def name
    "#{base_token.symbol}/#{quote_token.symbol}"
  end

  def latest_price
    update_price if price_stale?
    current_price
  end

  def moving_average(minutes = 5)
    # Get prices recorded within the specified time window
    start_time = minutes.minutes.ago
    recent_prices = token_pair_prices.where('created_at >= ?', start_time).order(created_at: :desc)
    
    # Return nil if no prices are available in the time window
    #return nil if recent_prices.empty? || recent_prices.count < 2
    return nil if recent_prices.empty? || recent_prices.count < minutes
    
    # Calculate the average of the available price values
    total = recent_prices.sum(&:price)
    average = total / recent_prices.count
    
    return average
  end

  private

  def price_stale?
    #price_updated_at.nil? || price_updated_at < 1.minute.ago
    price_updated_at.nil? || price_updated_at < 30.seconds.ago
  end

  def update_price
    TokenPriceService.update_price_for_pair(self)
  end
end
