class ProviderUrlService
  PROVIDER_URLS = Rails.application.credentials.dig(:ethereum)

  def self.get_provider_url(chain_name)
    PROVIDER_URLS[chain_name] || raise("No provider URL configured for chain: #{chain_name}")
  end
end
