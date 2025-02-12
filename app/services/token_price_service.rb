class TokenPriceService
  def self.get_price(base_token, quote_token, chain)
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    result = EthersService.get_token_price_with_params(
      base_token.contract_address,
      base_token.decimals,
      quote_token.contract_address,
      quote_token.decimals,
      provider_url
    )
    result["price"]
  end

  def self.update_price_for_pair(token_pair)
    provider_url = ProviderUrlService.get_provider_url(token_pair.chain.name)
    
    if pool_stale?(token_pair)
      # If pool info is stale, call the full price function (which returns pool info too)
      result = EthersService.get_token_price(token_pair, provider_url)
      token_pair.update!(
        current_price: result["price"].to_d,
        price_updated_at: Time.current,
        pool_address: result["poolAddress"],
        fee_tier: result["feeTier"],
        pool_address_updated_at: Time.current
      )
    else
      # Otherwise, use the cached pool info to get an updated price
      new_price = EthersService.get_token_price_from_pool(token_pair, provider_url)
      token_pair.update!(
        current_price: new_price.to_d,
        price_updated_at: Time.current
      )
    end
  end

  private

  def self.pool_stale?(token_pair)
    token_pair.pool_address_updated_at.nil? || token_pair.pool_address_updated_at < 1.day.ago
  end
end
