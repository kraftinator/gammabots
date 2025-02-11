class Token < ApplicationRecord
  belongs_to :chain

  has_many :base_token_pairs, class_name: "TokenPair", foreign_key: "base_token_id", dependent: :destroy
  has_many :quote_token_pairs, class_name: "TokenPair", foreign_key: "quote_token_id", dependent: :destroy

  # Callbacks
  before_validation :normalize_contract_address

  # Validations
  validates :name, presence: true
  validates :contract_address, presence: true, uniqueness: { scope: :chain_id }
  validates :decimals, presence: true, numericality: { only_integer: true }
  validates :symbol, presence: true, uniqueness: { scope: :chain_id }

  def self.create_from_contract_address(contract_address, chain)
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    token_details = EthersService.get_token_details(contract_address, provider_url)
    unless token_details
      Rails.logger.warn("Token details not found for contract address #{contract_address} on chain #{chain.name}")
      return nil
    end
    
    create!(
      chain: chain,
      symbol: token_details["symbol"],
      name: token_details["name"],
      decimals: token_details["decimals"],
      contract_address: contract_address
    )
  end

  private

  def normalize_contract_address
    self.contract_address = contract_address.to_s.downcase if contract_address.present?
  end
end
