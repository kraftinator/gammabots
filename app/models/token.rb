class Token < ApplicationRecord
  belongs_to :chain

  has_many :base_token_pairs, class_name: "TokenPair", foreign_key: "base_token_id", dependent: :destroy
  has_many :quote_token_pairs, class_name: "TokenPair", foreign_key: "quote_token_id", dependent: :destroy

  # Validations
  validates :symbol, presence: true
  validates :name, presence: true
  validates :contract_address, presence: true, uniqueness: { scope: :chain_id }
  validates :decimals, presence: true, numericality: { only_integer: true }

  # Associations
  validates_uniqueness_of :symbol, scope: :chain_id
end
