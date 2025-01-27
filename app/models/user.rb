class User < ApplicationRecord
  has_many :wallets, dependent: :destroy
  has_many :bots, dependent: :destroy

  validates :farcaster_id, presence: true, uniqueness: true
end
