class Chain < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :native_chain_id, presence: true, uniqueness: true
end
