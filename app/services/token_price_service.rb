class TokenPriceService
  def self.get_price(base_token, quote_token, chain)
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    EthersService.get_token_price_with_params(
      base_token.contract_address,
      base_token.decimals,
      quote_token.contract_address,
      quote_token.decimals,
      provider_url
    )
  end
end
