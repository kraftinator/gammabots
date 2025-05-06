class Bot < ApplicationRecord
  # Associations
  belongs_to :chain
  belongs_to :user
  belongs_to :token_pair
  belongs_to :strategy
  has_many :bot_events
  has_many :trades

  # Validations
  validates :initial_buy_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :base_token_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :quote_token_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :last_traded_at, presence: true, allow_nil: true

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def latest_trade
    trades.order(created_at: :desc).first
  end

  def last_sell_price
    trades.where(trade_type: "sell", status: "completed").order(created_at: :desc).first&.price
  end

  def last_buy_at
    trades.where(trade_type: "buy", status: "completed").order(created_at: :desc).first&.created_at
  end

  def initial_buy_made?
    #trades.where(trade_type: "buy").count > 0
    initial_buy_amount > 0 && trades.where(trade_type: "buy", status: "completed").count > 0
  end

  def buy_count
    trades.where(trade_type: "buy", status: "completed").count
  end

  def sell_count
    trades.where(trade_type: "sell", status: "completed").count
  end

  def process_trade(trade)
    return unless trade.completed?
    if trade.buy? && !initial_buy_made?
      process_initial_buy(trade)
    elsif trade.sell?
      process_sell(trade)
      # TODO: Update bot to indicate that it's done.
    end
  end

  def liquidate
    trade = TradeExecutionService.sell(self, base_token_amount, 0, provider_url)
    update!(active: false) if trade
    trade
  end

  def update_prices(current_price, current_moving_avg)
    if initial_buy_made?
      update!(
        lowest_price_since_creation: [lowest_price_since_creation, current_price].compact.min,
        highest_price_since_initial_buy: [highest_price_since_initial_buy, current_price].compact.max,
        lowest_price_since_initial_buy: [lowest_price_since_initial_buy, current_price].compact.min,
        highest_price_since_last_trade: [highest_price_since_last_trade, current_price].compact.max,
        lowest_price_since_last_trade: [lowest_price_since_last_trade, current_price].compact.min,
      
        lowest_moving_avg_since_creation: [lowest_moving_avg_since_creation, current_moving_avg].compact.min,
        highest_moving_avg_since_initial_buy: [highest_moving_avg_since_initial_buy, current_moving_avg].compact.max,
        lowest_moving_avg_since_initial_buy: [lowest_moving_avg_since_initial_buy, current_moving_avg].compact.min,
        highest_moving_avg_since_last_trade: [highest_moving_avg_since_last_trade, current_moving_avg].compact.max,
        lowest_moving_avg_since_last_trade: [lowest_moving_avg_since_last_trade, current_moving_avg].compact.min
      )
    else
      update!(
        lowest_price_since_creation: [lowest_price_since_creation, current_price].compact.min,
        lowest_moving_avg_since_creation: [lowest_moving_avg_since_creation, current_moving_avg].compact.min
      )
    end
  end

  def provider_url
    ProviderUrlService.get_provider_url(chain.name)
  end

  def strategy_variables
    {
      cpr: token_pair.latest_price,
      ppr: token_pair.previous_price || Float::NAN,
      ibp: initial_buy_price,
      bcn: buy_count,
      scn: sell_count,
      bta: base_token_amount,
      mam: moving_avg_minutes,
      vst: token_pair.volatility(moving_avg_minutes) || Float::NAN,
      vlt: token_pair.volatility(moving_avg_minutes*2) || Float::NAN,
      # prices
      lps: lowest_price_since_creation,
      hip: highest_price_since_initial_buy,
      hlt: highest_price_since_last_trade,
      lip: lowest_price_since_initial_buy,
      llt: lowest_price_since_last_trade,
      # moving averages
      cma: token_pair.moving_average(moving_avg_minutes) || Float::NAN,
      lma: token_pair.moving_average(moving_avg_minutes*2) || Float::NAN,
      lmc: lowest_moving_avg_since_creation || Float::NAN,
      hma: highest_moving_avg_since_initial_buy,
      lmi: lowest_moving_avg_since_initial_buy,
      hmt: highest_moving_avg_since_last_trade,
      lmt: lowest_moving_avg_since_last_trade,

      lta: last_traded_at,
      lba: last_buy_at,
      lsp: last_sell_price,
      crt: created_at,
      bot: self,
      provider_url: provider_url
    }
  end

  def strategy_json
    strategy.strategy_json
  end

  def min_amount_out_for_initial_buy
    (quote_token_amount / token_pair.current_price) * 0.95
  end

  private

  def process_initial_buy(trade)
    trade_price = trade.price
    update!(
      initial_buy_amount: trade.amount_in,
      quote_token_amount: 0,
      base_token_amount: trade.amount_out,
      initial_buy_price: trade_price,
      # prices
      highest_price_since_initial_buy: trade_price,
      lowest_price_since_initial_buy: trade_price,
      highest_price_since_last_trade: trade_price,
      lowest_price_since_last_trade: trade_price,
      # moving averages
      highest_moving_avg_since_initial_buy: trade_price,
      lowest_moving_avg_since_initial_buy: trade_price,
      highest_moving_avg_since_last_trade: trade_price,
      lowest_moving_avg_since_last_trade: trade_price,

      last_traded_at: trade.created_at
    )
  end

  def process_sell(trade)
    new_base_token_amount = base_token_amount - trade.amount_in
    # If the difference is negative but nearly zero, set it to 0
    new_base_token_amount = 0 if new_base_token_amount < 0 && new_base_token_amount.abs < 1e-9
    
    update!(
      base_token_amount: new_base_token_amount,
      quote_token_amount: quote_token_amount + trade.amount_out,
      highest_price_since_last_trade: trade.price,
      lowest_price_since_last_trade: trade.price,
      highest_moving_avg_since_last_trade: trade.price,
      lowest_moving_avg_since_last_trade: trade.price,

      last_traded_at: trade.created_at
    )
  end
end
