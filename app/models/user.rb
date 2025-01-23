class User < ApplicationRecord
  validates :farcaster_id, presence: true, uniqueness: true
end
