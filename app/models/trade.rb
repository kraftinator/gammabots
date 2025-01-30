class Trade < ApplicationRecord
  belongs_to :bot

  validates :trade_type, presence: true, inclusion: { in: %w[buy sell] }
  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }
  validates :price, numericality: { greater_than: 0 }
  validates :amount, numericality: { greater_than: 0 }
  validates :total_value, numericality: { greater_than: 0 }
  validates :executed_at, presence: true

  def pending?
    status == "pending"
  end
  
  def token_pair
    bot.token_pair
  end
end
