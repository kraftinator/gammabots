class Chain < ApplicationRecord 
  has_many :tokens, dependent: :destroy
  has_many :token_pairs, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :native_chain_id, presence: true, uniqueness: true
end
