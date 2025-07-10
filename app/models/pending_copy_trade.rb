class PendingCopyTrade < ApplicationRecord
  belongs_to :chain
  # Validations
  validates :wallet_address, presence: true
  validates :token_address, presence: true
  validates :amount_out, presence: true, numericality: { greater_than: 0 }
  validates :tx_hash, presence: true, uniqueness: true
  validates :block_number, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing valid invalid] }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :valid, -> { where(status: 'valid') }
  scope :invalid, -> { where(status: 'invalid') }
  scope :ready_to_process, -> { pending.order(:created_at) }
 
  # Status management
  def process!
    update!(status: 'processing')
  end

  def mark_valid!
    update!(status: 'valid')
  end

  def mark_invalid!
    update!(status: 'invalid')
  end
end