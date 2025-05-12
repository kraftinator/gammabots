class Trade < ApplicationRecord
  CONFIRMATION_DELAY = 5.seconds

  belongs_to :bot
  belongs_to :bot_cycle
  before_validation :assign_bot_cycle, on: :create
  after_commit :schedule_confirmation, :enqueue_infinite_approval, on: :create
  after_update :clear_reset_request_on_failed_sell, if: :saved_change_to_status?

  validates :trade_type, presence: true, inclusion: { in: %w[buy sell] }
  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }

  validates :price, numericality: { greater_than: 0 }, if: -> { completed? }
  validates :amount_in, numericality: { greater_than: 0 }, if: -> { completed? }
  validates :amount_out, numericality: { greater_than: 0 }, if: -> { completed? }
  validates :total_value, numericality: { greater_than: 0 }, if: -> { completed? }

  validates :executed_at, presence: true

  def pending?
    status == "pending"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def buy?
    trade_type == "buy"
  end
  
  def sell?
    trade_type == "sell"
  end
  
  def token_pair
    bot.token_pair
  end

  def total_value
    amount_out * price
  end

  private

  def schedule_confirmation
    ConfirmTradeJob.set(wait: CONFIRMATION_DELAY).perform_later(self.id)
  end

  def enqueue_infinite_approval
    return unless buy?
    ApprovalManager.ensure_infinite!(
      wallet:       bot.user.wallet_for_chain(bot.chain),
      token:        bot.token_pair.base_token,
      provider_url: bot.provider_url
    )
  end

  def assign_bot_cycle
    self.bot_cycle = bot.current_cycle
  end

  def clear_reset_request_on_failed_sell
    return unless sell? && failed?
    bot_cycle.update!(reset_requested_at: nil)
  end
end
