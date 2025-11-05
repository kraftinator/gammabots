# app/services/create_token_pair_service.rb
class CreateTokenPairService
  # Call with:
  #   CreateTokenPairService.call(
  #     token_address: "0x...",
  #     chain: Chain.find_by(name: 'base_mainnet')
  #   )
  def self.call(token_address:, chain:)
    # Normalize token address
    token_address = token_address.downcase

    token = Token.find_by(chain: chain, contract_address: token_address)
    if token.nil?
      token = Token.create_with_validation(contract_address: token_address, chain: chain)
      return unless token
    end

    return unless token.active?

    quote_token = Token.find_by(chain: chain, symbol: 'WETH')
    raise ArgumentError, "Invalid quote token" unless quote_token

    token_pair = TokenPair.find_by(chain: chain, base_token: token, quote_token: quote_token)
    unless token_pair
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

    unless result["poolAddress"] && result["feeTier"]
      puts "Cannot find pool"
      return false
    end

    price = EthersService.get_token_price_from_pool_with_fields(
      base_token.contract_address,
      base_token.decimals,
      quote_token.contract_address,
      quote_token.decimals,
      result["poolAddress"],
      provider_url
    )

    unless price
      puts "Cannot get price for #{base_token.symbol}/#{quote_token.symbol}"
      return false
    end

    price = price.to_d
    test_amount = 0.5
    sim = EthersService.quote_meets_minimum(
      quote_token.contract_address,
      base_token.contract_address,
      result["feeTier"],
      test_amount,
      quote_token.decimals,
      base_token.decimals,
      (test_amount / price) * 0.5,
      provider_url
    )

    return false unless sim['success']

    if sim['valid']
      return true
    else
      puts "Insufficient liquidity for #{base_token.symbol}/#{quote_token.symbol}"
      return false
    end
  end
end