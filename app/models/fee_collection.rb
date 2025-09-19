class FeeCollection < ApplicationRecord
  belongs_to :trade

  # Use positional args (Rails 7.2+) and correct options
  enum :status, {
    pending: "pending",
    collected: "collected",
    failed: "failed"
  }, prefix: :collection

  enum :unwrap_status, {
    pending: "pending",
    unwrapped: "unwrapped",
    failed: "failed"
  }, prefix: :unwrap

  # Validations
  validates :amount, numericality: { greater_than: 0 }
  validates :status, :unwrap_status, presence: true

  validates :tx_hash, presence: true, if: -> { collection_collected? }
  validates :unwrap_tx_hash, presence: true, if: -> { unwrap_unwrapped? }

  # Scopes
  scope :pending_collection, -> { where(status: "pending") }
  scope :pending_unwrap, -> { where(unwrap_status: "pending") }
end