class ProfitWithdrawal < ApplicationRecord
  belongs_to :bot
  belongs_to :bot_cycle
  belongs_to :payout_token, class_name: "Token", optional: true

  # ---- ENUMS ----
  enum :convert_status, {
    pending:   "pending",
    converted: "converted",
    failed:    "failed"
  }, prefix: :convert

  enum :transfer_status, {
    pending:    "pending",
    transferred:"transferred",
    failed:     "failed"
  }, prefix: :transfer

  validates :raw_profit, :profit_share, :amount_withdrawn, presence: true
  validates :raw_profit, :amount_withdrawn, numericality: { greater_than_or_equal_to: 0 }
  validates :profit_share, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :convert_status, :transfer_status, presence: true
  validates :convert_tx_hash, presence: true, if: -> { convert_converted? }
  validates :transfer_tx_hash, presence: true, if: -> { transfer_transferred? }

  # ---- SCOPES ----
  scope :pending_convert,  -> { where(convert_status: "pending") }
  scope :pending_transfer, -> { where(transfer_status: "pending") }

  # ---- HELPERS ----
  def payout_asset
    payout_token&.symbol || "ETH"
  end
end