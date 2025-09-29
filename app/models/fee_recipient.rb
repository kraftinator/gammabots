class FeeRecipient < ApplicationRecord
  belongs_to :fee_collection

  # Recipient types
  enum :recipient_type, {
    platform: "platform",
    strategy_owner: "strategy_owner",
    token_owner: "token_owner"
  }, prefix: :recipient

  # Status lifecycle
  enum :status, {
    pending: "pending",       # created, not yet sent
    submitted: "submitted",   # tx broadcasted, waiting for confirm
    confirmed: "confirmed",   # transfer succeeded
    failed: "failed"          # transfer failed
  }, prefix: true

  # Validations
  validates :recipient_type, :recipient_address, :amount, :status, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :recipient_address, format: { with: /\A0x[a-fA-F0-9]{40}\z/, message: "must be a valid Ethereum address" }

  # Scopes
  scope :pending, -> { where(status: "pending") }
  scope :submitted, -> { where(status: "submitted") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :failed, -> { where(status: "failed") }

  # Convenience
  def eth_amount
    amount.to_d.round(18, BigDecimal::ROUND_DOWN)
  end
end