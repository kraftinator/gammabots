class ProfitWithdrawal < ApplicationRecord
  belongs_to :bot
  belongs_to :bot_cycle

  validates :raw_profit, :profit_share, :amount_withdrawn, presence: true
  validates :raw_profit, :amount_withdrawn, numericality: { greater_than_or_equal_to: 0 }
  validates :profit_share, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
end
