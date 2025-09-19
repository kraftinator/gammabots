class Wallet < ApplicationRecord
  VALID_KINDS = %w[user router treasury].freeze

  belongs_to :user, optional: true
  belongs_to :chain
  has_many :token_approvals, dependent: :destroy

  before_validation :normalize_address

  encrypts :private_key

  validates :private_key, presence: true
  validates :address, presence: true, uniqueness: true, 
    format: { with: /\A0x[a-f0-9]{40}\z/, message: "must be a valid Ethereum address" }
  validates :kind, inclusion: { in: VALID_KINDS }

  def wallet_address
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    EthersService.get_wallet_address(private_key, provider_url)
  end

  private
  
  def normalize_address
    self.address = address.downcase if address.present?
  end
end
