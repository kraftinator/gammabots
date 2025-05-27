class Bot < ApplicationRecord
  # Associations
  belongs_to :chain
  belongs_to :user
  belongs_to :token_pair
  belongs_to :strategy
  has_many :bot_cycles
  has_many :bot_events
  has_many :trades

  # Validations
  validates :initial_buy_amount, numericality: { greater_than_or_equal_to: 0 }
  #validates :base_token_amount, numericality: { greater_than_or_equal_to: 0 }
  #validates :quote_token_amount, numericality: { greater_than_or_equal_to: 0 }
  #validates :last_traded_at, presence: true, allow_nil: true

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
    current_cycle.initial_buy_made?
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
      process_reset if current_cycle.reset_requested_at
      # TODO: Update bot to indicate that it's done.
    end
  end

  def liquidate
    trade = TradeExecutionService.sell(current_cycle.strategy_variables.merge({ step: 0 }), current_cycle.base_token_amount, 0)
    deactivate if trade
    trade
  end

  def deactivate
    take_profit(split: false)
    update!(active: false)
    current_cycle.update!(ended_at: Time.current)
  end

  def activate
    update!(active: true)
    current_cycle.update!(ended_at: nil)
  end

  def reset
    current_cycle.update!(reset_requested_at: Time.current)
  end

  def update_prices(current_price, current_moving_avg)
    bot_cycle = current_cycle
    if initial_buy_made?
      bot_cycle.update!(
        lowest_price_since_creation: [bot_cycle.lowest_price_since_creation, current_price].compact.min,
        highest_price_since_initial_buy: [bot_cycle.highest_price_since_initial_buy, current_price].compact.max,
        lowest_price_since_initial_buy: [bot_cycle.lowest_price_since_initial_buy, current_price].compact.min,
        highest_price_since_last_trade: [bot_cycle.highest_price_since_last_trade, current_price].compact.max,
        lowest_price_since_last_trade: [bot_cycle.lowest_price_since_last_trade, current_price].compact.min,
      
        lowest_moving_avg_since_creation: [bot_cycle.lowest_moving_avg_since_creation, current_moving_avg].compact.min,
        highest_moving_avg_since_initial_buy: [bot_cycle.highest_moving_avg_since_initial_buy, current_moving_avg].compact.max,
        lowest_moving_avg_since_initial_buy: [bot_cycle.lowest_moving_avg_since_initial_buy, current_moving_avg].compact.min,
        highest_moving_avg_since_last_trade: [bot_cycle.highest_moving_avg_since_last_trade, current_moving_avg].compact.max,
        lowest_moving_avg_since_last_trade: [bot_cycle.lowest_moving_avg_since_last_trade, current_moving_avg].compact.min
      )
    else
      bot_cycle.update!(
        lowest_price_since_creation: [bot_cycle.lowest_price_since_creation, current_price].compact.min,
        lowest_moving_avg_since_creation: [bot_cycle.lowest_moving_avg_since_creation, current_moving_avg].compact.min
      )
    end
  end

  def provider_url
    ProviderUrlService.get_provider_url(chain.name)
  end

  def strategy_variables(use_cached_price: false)
    current_cycle.strategy_variables(use_cached_price: use_cached_price)
  end

  def latest_strategy_variables
    latest_cycle.strategy_variables(use_cached_price: true)
  end

  def strategy_json
    strategy.strategy_json
  end

  def min_amount_out_for_initial_buy
    (current_cycle.quote_token_amount / token_pair.current_price) * 0.95
  end

  def current_cycle
    bot_cycles.order(created_at: :desc).first
  end

  def latest_cycle
    bot_cycles.order(created_at: :desc).first
  end

  def first_cycle?
    bot_cycles.count == 1
  end

  def initial_amount
    bot_cycles.order(created_at: :asc).first.initial_buy_amount
  end

  def last_action_at
    trade = trades.where(status: "completed").order(created_at: :desc).first
    trade ? trade.executed_at : created_at
  end

  def current_value
    total_value = current_cycle.base_token_amount * token_pair.current_price
    total_value += current_cycle.quote_token_amount
    total_value
  end

  def profit_percentage
    # guard against divide-by-zero
    return 0.0 if initial_buy_amount.to_f.zero?

    # ((current – initial) / initial) × 100, rounded to 2 decimal places
    change    = current_value - initial_buy_amount.to_f
    percent   = change / initial_buy_amount.to_f * 100
    percent.round(2)
  end

  def profit_fraction
    return 0.0 if initial_buy_amount.to_f.zero?
    (current_value - initial_buy_amount.to_f) / initial_buy_amount.to_f
  end

  private

  def process_initial_buy(trade)
    trade_price = trade.price
    moving_avg = token_pair.moving_average(moving_avg_minutes)
    cycle = current_cycle

    new_quote_token_amount = cycle.quote_token_amount - trade.amount_in
    new_base_token_amount = cycle.base_token_amount + trade.amount_out

    cycle.update!(
      # amounts
      initial_buy_amount: trade.amount_in,                 # ETH
      quote_token_amount: [new_quote_token_amount, 0].max, # ETH
      base_token_amount: [new_base_token_amount, 0].max,   # token
      #quote_token_amount: 0,                # ETH
      #base_token_amount: trade.amount_out,  # token

      initial_buy_price: trade_price,
      # prices
      highest_price_since_initial_buy: trade_price,
      lowest_price_since_initial_buy: trade_price,
      highest_price_since_last_trade: trade_price,
      lowest_price_since_last_trade: trade_price,
      # moving averages
      highest_moving_avg_since_initial_buy: moving_avg,
      lowest_moving_avg_since_initial_buy: moving_avg,
      highest_moving_avg_since_last_trade: moving_avg,
      lowest_moving_avg_since_last_trade: moving_avg
    )
  end

  def process_sell(trade)
    bot_cycle = current_cycle
    new_base_token_amount = bot_cycle.base_token_amount - trade.amount_in
    # If the difference is negative but nearly zero, set it to 0
    new_base_token_amount = 0 if new_base_token_amount < 0 && new_base_token_amount.abs < 1e-9
    
    trade_price = trade.price
    moving_avg = token_pair.moving_average(moving_avg_minutes)

    bot_cycle.update!(
      base_token_amount: new_base_token_amount,
      quote_token_amount: bot_cycle.quote_token_amount + trade.amount_out,
      highest_price_since_last_trade: trade_price,
      lowest_price_since_last_trade: trade_price,
      highest_moving_avg_since_last_trade: moving_avg,
      lowest_moving_avg_since_last_trade: moving_avg
    )
  end

  def process_reset
    take_profit(split: true)

    old_cycle = current_cycle
    old_cycle.update!(ended_at: Time.current)

    current_price = token_pair.latest_price
    moving_avg = token_pair.moving_average(moving_avg_minutes)
    bot_cycles.create!(
      started_at: Time.current,
      base_token_amount: old_cycle.base_token_amount,
      quote_token_amount: old_cycle.quote_token_amount,
      created_at_price: current_price,
      lowest_price_since_creation: current_price,
      lowest_moving_avg_since_creation: moving_avg
    )
  end

  def take_profit(split:)
    cycle = current_cycle
    return unless cycle && profit_fraction > 0.10

    # compute raw profit
    profit = cycle.quote_token_amount - initial_buy_amount
    amount_to_send = split ? (profit / 2.0) : profit

    puts "amount_to_send: #{amount_to_send.to_s}"

    # perform the on-chain transfer
    tx = EthersService.send_erc20(
      user.wallet_for_chain(chain),
      token_pair.quote_token.contract_address,
      user.created_by_wallet,
      amount_to_send,
      token_pair.quote_token.decimals,
      provider_url
    )

    puts "tx: #{tx.inspect}"

    # log the event
    bot_events.create!(
      event_type: 'profit_sent',
      payload: {
        split: split,
        sent_amount: amount_to_send,
        tx_hash: tx['txHash']
      }
    )

    # subtract the sent ETH so it's not reinvested
    cycle.update!(
      quote_token_amount: cycle.quote_token_amount - amount_to_send
    )
  end
end
