class Wallet < ApplicationRecord
  belongs_to :user
  belongs_to :chain

  encrypts :private_key

  validates :private_key, presence: true

  def wallet_address
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    EthersService.get_wallet_address(private_key, provider_url)
  end
end
