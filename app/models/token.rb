class Token < ApplicationRecord
  belongs_to :chain
  has_many :token_approvals, dependent: :destroy

  has_many :base_token_pairs, class_name: "TokenPair", foreign_key: "base_token_id", dependent: :destroy
  has_many :quote_token_pairs, class_name: "TokenPair", foreign_key: "quote_token_id", dependent: :destroy

  # Callbacks
  before_validation :normalize_contract_address

  # Validations
  validates :status, presence: true, inclusion: { in: %w[active rejected] }
  validates :name, presence: true
  validates :contract_address, presence: true, uniqueness: { scope: :chain_id }
  validates :decimals, presence: true, numericality: { only_integer: true }
  validates :symbol, presence: true

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

  def self.create_with_validation(contract_address:, chain:)
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    token_details = EthersService.get_token_details(contract_address, provider_url)
    unless token_details
      Rails.logger.warn("Token details not found for contract address #{contract_address} on chain #{chain.name}")
      return nil
    end

    zero_ex_api_key = Rails.application.credentials.dig(:zero_ex, :api_key)
    taker_wallet = Wallet.find_by!(kind: 'validator', chain: chain)
    result = EthersService.validate_token(taker_wallet.address, contract_address, token_details["decimals"], zero_ex_api_key, provider_url)

    if result["success"]
      status  = result["verdict"] == "accept" ? "active" : "rejected"
      create!(
        chain: chain,
        symbol: token_details["symbol"],
        name: token_details["name"],
        decimals: token_details["decimals"],
        contract_address: contract_address,
        status: result["verdict"] == "accept" ? "active" : "rejected",
        validation_payload: result,
        last_validated_at: Time.current
      )
    else
      Rails.logger.warn("Validation attempt failed for #{contract_address} on chain #{chain.name}")
      return nil
    end
  end

  def validate
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    zero_ex_api_key = Rails.application.credentials.dig(:zero_ex, :api_key)
    taker_wallet = Wallet.find_by!(kind: 'validator', chain: chain)

    result = EthersService.validate_token(taker_wallet.address, contract_address, decimals, zero_ex_api_key, provider_url)

    if result["success"]
      update!(
        status: result["verdict"] == "accept" ? "active" : "rejected",
        validation_payload: result,
        last_validated_at: Time.current
      )
    else
      Rails.logger.warn("Validation attempt failed for #{contract_address} on chain #{chain.name}")
      return nil
    end
  end

  def active?
    status == "active"
  end

  def fetch_validation_payload
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    zero_ex_api_key = Rails.application.credentials.dig(:zero_ex, :api_key)
    taker_wallet = Wallet.find_by!(kind: 'validator', chain: chain)

    EthersService.validate_token(taker_wallet.address, contract_address, decimals, zero_ex_api_key, provider_url)
  end

  def self.validation_payload_by_params(contract_address, decimals)
    chain = Chain.find_by(name: 'base_mainnet')
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    zero_ex_api_key = Rails.application.credentials.dig(:zero_ex, :api_key)
    taker_wallet = Wallet.find_by!(kind: 'validator', chain: chain)
 
    EthersService.validate_token(taker_wallet.address, contract_address, decimals, zero_ex_api_key, provider_url)
  end

  private

  def normalize_contract_address
    self.contract_address = contract_address.to_s.downcase if contract_address.present?
  end
end
