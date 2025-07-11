# app/models/copy_trade.rb
class CopyTrade < ApplicationRecord
  belongs_to :token_pair
  
  validates :wallet_address, presence: true
  validates :tx_hash, presence: true, uniqueness: true
  validates :block_number, presence: true
  validates :amount_out, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_wallet, ->(address) { where(wallet_address: address) }
end