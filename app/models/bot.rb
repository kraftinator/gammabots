class Bot < ApplicationRecord
  # Associations
  belongs_to :chain
  belongs_to :user
  belongs_to :token_pair
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

  def initial_buy_made?
    initial_buy_amount > 0
  end

  def process_trade(trade)
    return unless trade.completed?
    if trade.buy? && !initial_buy_made?
      process_initial_buy(trade)
    elsif trade.sell?
      process_sell(trade)
    end
  end

  def update_prices(current_price)
    update!(
      highest_price_since_initial_buy: [highest_price_since_initial_buy, current_price].compact.max,
      lowest_price_since_initial_buy: [lowest_price_since_initial_buy, current_price].compact.min,
      highest_price_since_last_trade: [highest_price_since_last_trade, current_price].compact.max,
      lowest_price_since_last_trade: [lowest_price_since_last_trade, current_price].compact.min
    )
  end

  def provider_url
    ProviderUrlService.get_provider_url(chain.name)
  end

  def strategy_variables
    {
      cp: token_pair.latest_price,
      ib: initial_buy_price,
      st: trades.where(trade_type: "sell").count,
      ba: base_token_amount,
      hib: highest_price_since_initial_buy,
      bot: self,
      provider_url: provider_url
    }
  end

  private

  def process_initial_buy(trade)
    trade_price = trade.price
    update!(
      initial_buy_amount: trade.total_value,
      quote_token_amount: 0,
      base_token_amount: trade.amount_out,
      initial_buy_price: trade_price,
      highest_price_since_initial_buy: trade_price,
      lowest_price_since_initial_buy: trade_price,
      highest_price_since_last_trade: trade_price,
      lowest_price_since_last_trade: trade_price,
      last_traded_at: trade.created_at
    )
  end

  def process_sell(trade)
    trade_price = trade.price
    update!(
      base_token_amount: base_token_amount - trade.amount_in,
      quote_token_amount: quote_token_amount + trade.amount_out,
      highest_price_since_last_trade: trade_price,
      lowest_price_since_last_trade: trade_price,
      last_traded_at: trade.created_at
    )
  end
end
