class Wallet < ApplicationRecord
  belongs_to :user
  belongs_to :chain

  before_validation :normalize_address

  encrypts :private_key

  validates :private_key, presence: true
  validates :address, presence: true, uniqueness: true, 
    format: { with: /\A0x[a-f0-9]{40}\z/, message: "must be a valid Ethereum address" }

  def wallet_address
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    EthersService.get_wallet_address(private_key, provider_url)
  end

  private
  
  def normalize_address
    self.address = address.downcase if address.present?
  end
end
