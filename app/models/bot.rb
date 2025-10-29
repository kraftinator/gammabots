class Bot < ApplicationRecord
  DEFAULT_PROFIT_THRESHOLD = 0.01
  CONFIRMATION_DELAY = 5.seconds

  # Associations
  belongs_to :chain
  belongs_to :user
  belongs_to :token_pair, optional: true
  belongs_to :strategy
  has_many :bot_cycles
  has_many :bot_events
  has_many :bot_price_metrics
  has_many :profit_withdrawals
  has_many :trades

  after_commit :enqueue_infinite_approval, on: :create

  # Validations
  validates :initial_buy_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :token_pair, presence: true, if: :default_bot?
  validates :copy_wallet_address, presence: true, if: :copy_bot?

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :copy_bots, -> { where(bot_type: 'copy') }
  scope :default_bots, -> { where(bot_type: 'default') }
  scope :funding_pending, -> { where(status: 'pending_funding') }
  scope :unfunded, -> { where(status: ['pending_funding', 'converting_to_weth']) }

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

  def completed_trade_count
    trades.where(status: "completed").count
  end

  def process_trade(trade)
    return unless trade.completed?
    if trade.buy? && !initial_buy_made?
      process_initial_buy(trade)
    elsif trade.sell?
      process_sell(trade)
      #process_reset if current_cycle.reset_requested_at
      PostSellService.call(self, trade)
    end
  end

  def liquidate
    trade = TradeExecutionService.sell(current_cycle.strategy_variables.merge({ step: 0 }), current_cycle.base_token_amount, 0)
    deactivate if trade
    trade
  end

  def deactivate
    update!(active: false)
    reset
  end

  def forced_deactivate
    update!(active: false)
    take_profit(full_share: true)
    current_cycle.update!(ended_at: Time.current)
    return_funds_to_user
  end

  def return_funds_to_user
    BotFunds::UnwrapWethJob.set(wait: CONFIRMATION_DELAY).perform_later(self.id)
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
        highest_price_since_creation: [bot_cycle.highest_price_since_creation, current_price].compact.max,
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
        highest_price_since_creation: [bot_cycle.highest_price_since_creation, current_price].compact.max,
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
    trade ? trade.executed_at : updated_at
  end

  def current_value
    total_value = current_cycle.base_token_amount * token_pair.current_price
    total_value += current_cycle.quote_token_amount
    total_value
  end

  def profit_taken
    profit_withdrawals.sum(:amount_withdrawn)
  end

  def profit_fraction(include_profit_withdrawals: false)
    return 0.0 if initial_buy_amount.to_f.zero?

    change = effective_current_value - initial_buy_amount.to_f
    change += profit_taken if include_profit_withdrawals
    change / initial_buy_amount.to_f
  end

  def profit_percentage(include_profit_withdrawals: false)
    (profit_fraction(include_profit_withdrawals: include_profit_withdrawals) * 100).round(2)
  end

  def effective_current_value
    if active
      current_value
    else
      funds_returned_amount + current_value
    end
  end

=begin
  def profit_percentage(include_profit_withdrawals: false)
    # guard against divide-by-zero
    return 0.0 if initial_buy_amount.to_f.zero?

    change    = current_value - initial_buy_amount.to_f
    change += profit_taken if include_profit_withdrawals
    percent   = change / initial_buy_amount.to_f * 100
    percent.round(2)
  end

  def profit_fraction
    return 0.0 if initial_buy_amount.to_f.zero?
    (current_value - initial_buy_amount.to_f) / initial_buy_amount.to_f
  end
=end

  #{ "c":"bcn>0 && lba>5 && bpp<=0 && cpr<ibp0.99","a":["sell all","reset"] },
  #{ "c":"bcn>0 && lba>5 && bpp>0  && cpr<bep",   "a":["sell all","reset"] }
  def break_even_price
    return nil unless initial_buy_made?

    cycle = current_cycle
    return nil unless cycle
    #return nil if cycle.first_cycle?

    base_amount  = cycle.base_token_amount
    quote_amount = cycle.quote_token_amount
    return nil if base_amount.zero?

    ((initial_buy_amount - quote_amount) / base_amount).round(18)
  end

  def copy_bot?
    bot_type == 'copy'
  end
  
  def default_bot?
    bot_type == 'default'
  end

  def pending_funding?
    status == 'pending_funding'
  end

  def unfunded?
    status == 'pending_funding' || status == 'converting_to_weth'
  end

  def process_reset
    active? ? take_profit : take_profit(full_share: true)

    old_cycle = current_cycle
    old_cycle.update!(ended_at: Time.current)

    return unless active

    current_price = token_pair.latest_price
    moving_avg = token_pair.moving_average(moving_avg_minutes)
    bot_cycles.create!(
      started_at: Time.current,
      base_token_amount: old_cycle.base_token_amount,
      quote_token_amount: old_cycle.quote_token_amount,
      created_at_price: current_price,
      highest_price_since_creation: current_price,
      lowest_price_since_creation: current_price,
      lowest_moving_avg_since_creation: moving_avg
    )
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

  def take_profit(full_share: false)
    cycle = current_cycle
    return unless cycle

    #return unless cycle && profit_fraction > profit_threshold
    threshold = active ? profit_threshold : DEFAULT_PROFIT_THRESHOLD
    return unless profit_fraction >= threshold

    # compute raw profit and share
    profit = cycle.quote_token_amount - initial_buy_amount
    share = full_share ? BigDecimal("1.0") : BigDecimal(profit_share.to_s)
    amount = profit * share

    # record the withdrawal
    payout_token = Token.find_by!(chain: chain, symbol: "USDC")
    withdrawal = ProfitWithdrawal.create!(
      bot:              self,
      bot_cycle:        cycle,
      raw_profit:       profit,
      profit_share:     share,
      amount_withdrawn: amount,
      payout_token:     payout_token
    )

    # Convert to USDC and send
    ProfitWithdrawals::ProfitConvertJob.perform_later(withdrawal.id)

    # subtract the sent amount so it's not reinvested
    cycle.update!(quote_token_amount: cycle.quote_token_amount - amount)
  end

  def enqueue_infinite_approval
    return unless token_pair
    ApprovalManager.ensure_infinite!(
      wallet:       user.wallet_for_chain(chain),
      token:        token_pair.quote_token,
      provider_url: provider_url
    )
  end
end
