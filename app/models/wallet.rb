class Wallet < ApplicationRecord
  belongs_to :user
  belongs_to :chain

  encrypts :private_key

  validates :private_key, presence: true
end
