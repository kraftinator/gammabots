class Trade < ApplicationRecord
  belongs_to :bot

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
end
