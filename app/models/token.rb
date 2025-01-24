class Token < ApplicationRecord
  belongs_to :chain

  # Validations
  validates :symbol, presence: true
  validates :name, presence: true
  validates :contract_address, presence: true, uniqueness: { scope: :chain_id }
  validates :decimals, presence: true, numericality: { only_integer: true }

  # Associations
  validates_uniqueness_of :symbol, scope: :chain_id
end
