# app/services/create_token_pair_service.rb
class CreateTokenPairService
  # Call with:
  #   CreateTokenPairService.call(
  #     token_address: "0x...",
  #     chain: Chain.find_by(name: 'base_mainnet')
  #   )
  def self.call(token_address:, chain:)
    provider_url = ProviderUrlService.get_provider_url(chain.name)

    # Normalize token address
    token_address = token_address.downcase

    token = Token.find_by(chain: chain, contract_address: token_address)
    if token.nil?
      token = Token.create_from_contract_address(token_address, chain)
      return unless token
    end

    quote_token = Token.find_by(chain: chain, symbol: 'WETH')
    raise ArgumentError, "Invalid quote token" unless quote_token

    token_pair = TokenPair.find_by(chain: chain, base_token: token, quote_token: quote_token)
    unless token_pair
      begin
        return unless valid_token_pair?(token, quote_token, provider_url)
      rescue RuntimeError => e
        return nil
      end

      token_pair = TokenPair.create!(
        chain: chain, 
        base_token: token, 
        quote_token: quote_token
      )

      token_pair.latest_price
    end

    token_pair
  end

  private

  def self.valid_token_pair?(base_token, quote_token, provider_url)
    result = EthersService.find_most_liquid_pool(
      base_token.contract_address, 
      quote_token.contract_address, 
      provider_url
    )
    result["poolAddress"] && result["feeTier"]
  end
end