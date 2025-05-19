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

=begin
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
=end

  # Simple Moving Average over the past `minutes` minutes,
  # aggregating multiple ticks per minute via averaging
  def moving_average(minutes = 5)
    # Define window to include the current minute and the previous minutes
    start_time = minutes.minutes.ago

    # Bucket ticks by minute and compute average price per bucket
    avg_prices = token_pair_prices
      .where('created_at >= ? AND created_at <= ?', start_time, Time.current)
      .group(Arel.sql("date_trunc('minute', created_at)"))
      .order(Arel.sql("date_trunc('minute', created_at) DESC"))
      .limit(minutes)             # take the latest `minutes` buckets
      .pluck(Arel.sql("AVG(price)"))

    # Ensure we have a full set of minutes
    return nil if avg_prices.size < minutes

    # Calculate the average of the minute-averages
    avg_prices.sum(0.0) / avg_prices.size
  end

  def volatility(minutes = 5)
    start_time = minutes.minutes.ago
    prices = token_pair_prices
      .where("created_at >= ?", start_time)
      .order(created_at: :desc)
      .pluck(:price)

    return nil if prices.empty? || prices.count < minutes

    (prices.max - prices.min) / prices.min.to_f
  end

  def previous_price
    ppr_record = token_pair_prices.order(created_at: :desc).offset(1).first
    ppr_record ? ppr_record.price : nil
  end

  #def rolling_high(minutes = 5)
  #  start_time = minutes.minutes.ago
  #  prices = token_pair_prices
  #             .where('created_at >= ?', start_time)
  #             .pluck(:price)

  #  return nil if prices.empty? || prices.count < minutes

   # prices.max
  #end
=begin
  # Highest price over the past `minutes` minutes (rolling high), excluding the latest price
  def rolling_high(minutes = 5)
    start_time = minutes.minutes.ago
    recent = token_pair_prices
               .where('created_at >= ?', start_time)
               .order(created_at: :desc)
               .offset(1)        # skip the most recent price
               .limit(minutes)   # take the next `minutes` prices
               .pluck(:price)

    return nil if recent.empty? || recent.count < minutes

    recent.max
  end
=end

  # Highest average price over the past `minutes` minutes (rolling high)
  # aggregates multiple ticks per minute into one bar via averaging
  def rolling_high(minutes = 5)
    # Expand window by 1 to include the current minute bucket before dropping it
    start_time = (minutes + 1).minutes.ago

    # Bucket ticks by minute and compute average price per bucket
    avg_prices = token_pair_prices
      .where('created_at >= ? AND created_at < ?', start_time, Time.current)
      .group(Arel.sql("date_trunc('minute', created_at)"))
      .order(Arel.sql("date_trunc('minute', created_at) DESC"))
      .offset(1)                  # skip the current minute bucket
      .limit(minutes)             # take the previous `minutes` buckets
      .pluck(Arel.sql("AVG(price)"))

    # Ensure we have a full set of minutes before calculating
    return nil if avg_prices.size < minutes

    avg_prices.max
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
