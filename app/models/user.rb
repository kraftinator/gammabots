class User < ApplicationRecord
  has_many :wallets, dependent: :destroy
  has_many :bots, dependent: :destroy

  validates :farcaster_id, presence: true, uniqueness: true

  # Scopes
  scope :active, -> { where(active: true) }

  def wallet_for_chain(chain)
    wallets.find_by(chain: chain)
  end
end
