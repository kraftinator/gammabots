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


  # Calculate the simple moving average over a window of `minutes` bars,
  # optionally shifted back by `shift` minutes (0 = include current bar).
  def moving_average(minutes = 5, shift: 0)
    # Determine time window end and start
    #end_time   = shift.minutes.ago
    #start_time = (minutes + shift).minutes.ago
    now        = Time.current.beginning_of_minute
    end_time   = now - shift.minutes
    start_time = end_time - minutes.minutes

    avg_prices = token_pair_prices
      .where('created_at >= ? AND created_at <= ?', start_time, end_time)
      .group(Arel.sql("date_trunc('minute', created_at)"))
      .order(Arel.sql("date_trunc('minute', created_at) DESC"))
      .limit(minutes)
      .pluck(Arel.sql('AVG(price)'))

    return nil if avg_prices.size < minutes

    avg_prices.sum(0.0) / avg_prices.size
  end
=end

  # Calculate the simple moving average over a window of `minutes` bars,
  # optionally shifted back by `shift` minutes (0 = include current bar).
  def moving_average(minutes = 6, shift: 0)
    # 1) Determine the end of the target window: the end of the minute `shift` minutes ago
    bucket_end   = shift.minutes.ago.end_of_minute
    # 2) Determine the start of the earliest minute bucket you want
    #    We need (minutes - 1) buckets before bucket_end, plus shift
    bucket_start = (minutes - 1 + shift).minutes.ago.beginning_of_minute

    # 3) Aggregate one average per minute‐bucket in the range
    per_minute_avgs = token_pair_prices
      .where(created_at: bucket_start..bucket_end)
      .group(Arel.sql("date_trunc('minute', created_at)"))
      .order(Arel.sql("date_trunc('minute', created_at) DESC"))
      .limit(minutes)
      .pluck(Arel.sql("AVG(price)"))

    # 4) If we don’t have a full set of `minutes` buckets, bail out
    return nil if per_minute_avgs.size < minutes

    # 5) Compute the SMA as the mean of those per-minute averages
    per_minute_avgs.sum(0.0) / per_minute_avgs.size
  end

  # Calculate the “volume diversity” over a window of `minutes` bars,
  # optionally shifted back by `shift` minutes (0 = include current bar).
  def volume_indicator(minutes = 5, shift: 0)
    # 1) Determine the end of the target window: end of the minute `shift` minutes ago
    bucket_end   = shift.minutes.ago.end_of_minute
    # 2) Determine the start of the earliest minute bucket you want
    bucket_start = (minutes - 1 + shift).minutes.ago.beginning_of_minute

    # 3) Build one aggregated price per minute‐bucket
    per_minute_avgs = token_pair_prices
      .where(created_at: bucket_start..bucket_end)
      .group(Arel.sql("date_trunc('minute', created_at)"))
      .order(Arel.sql("date_trunc('minute', created_at) DESC"))
      .limit(minutes)
      .pluck(Arel.sql("AVG(price)"))

    # 4) Bail out if we don’t have a full set of `minutes` buckets
    return nil if per_minute_avgs.size < minutes

    # 5) Compute the ratio of unique bars over total bars (== minutes)
    unique_count = per_minute_avgs.uniq.size
    unique_count.to_f / per_minute_avgs.size
  end

  def momentum_indicator(minutes = 5, shift: 0)
    # 1) Determine end of the window: end of the minute `shift` minutes ago
    bucket_end   = shift.minutes.ago.end_of_minute
    # 2) Determine start of the earliest minute bucket you want
    bucket_start = (minutes - 1 + shift).minutes.ago.beginning_of_minute

    # 3) Fetch all raw ticks in that time range, oldest first
    prices = token_pair_prices
      .where(created_at: bucket_start..bucket_end)
      .order(:created_at)
      .pluck(:price)

    # 4) Need at least two points to compute momentum
    return nil if prices.size < 2

    # 5) Count how many times price increased from one tick to the next
    increasing_count = prices.each_cons(2).count { |prev, curr| curr > prev }
    total_comparisons = prices.size - 1

    # 6) Return the ratio of increases
    increasing_count.to_f / total_comparisons
  end

  def volatility_by_range(minutes = 5)
    start_time = minutes.minutes.ago
    prices = token_pair_prices
      .where("created_at >= ?", start_time)
      .order(created_at: :desc)
      .pluck(:price)

    return nil if prices.empty? || prices.count < minutes

    (prices.max - prices.min) / prices.min.to_f
  end

  def volatility_by_std_dev(minutes = 5)
    start_time = minutes.minutes.ago
    prices = token_pair_prices
      .where("created_at >= ?", start_time)
      .order(created_at: :desc)
      .pluck(:price)

    # Need at least two prices to compute returns
    return nil if prices.size < 2

    # 1) compute simple returns between consecutive prices
    returns = prices.each_cons(2).map do |prev_price, cur_price|
      (cur_price - prev_price) / prev_price.to_f
    end

    # 2) mean of returns
    mean = returns.sum / returns.size.to_f

    # 3) variance (population)
    variance = returns.reduce(0.0) { |acc, r| acc + (r - mean)**2 } / returns.size.to_f

    # 4) std-dev
    Math.sqrt(variance)
  end

  def previous_price
    ppr_record = token_pair_prices.order(created_at: :desc).offset(1).first
    ppr_record ? ppr_record.price : nil
  end

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

  def price_non_decreasing?(minutes = 5, min_unique_points = 1)
    cutoff = minutes.minutes.ago
    prices = token_pair_prices
              .where("created_at >= ?", cutoff)
              .order(:created_at)
              .pluck(:price)
    return false if prices.size < minutes

    prices.each_cons(2).all? { |prev, curr| curr >= prev } && prices.uniq.size > min_unique_points
  end

  private

  def price_stale?
    return true if price_updated_at.nil?
    return true if price_updated_at < 30.seconds.ago
    return true if price_updated_at.beginning_of_minute < Time.current.beginning_of_minute

    false
  end

  def update_price
    TokenPriceService.update_price_for_pair(self)
  end
end
