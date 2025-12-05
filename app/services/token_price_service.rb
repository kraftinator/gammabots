class TokenPriceService
  DEFAULT_SELL_AMOUNT = BigDecimal("0.1")
  ZERO_EX_API_KEY = Rails.application.credentials.dig(:zero_ex, :api_key)

  def self.update_price(token_pair)
    result = get_price(token_pair)

    unless result["success"]
      puts "Failed to get price for #{token_pair.name}."
      puts "ERROR: #{result.inspect}"
      return false
    end

    #new_price = result["price"].to_d
    base_decimals  = token_pair.base_token.decimals
    quote_decimals = token_pair.quote_token.decimals

    # new_price is always ETH per base_token (e.g. WETH per RUNNER)
    new_price = eth_per_base_token(
      result,
      base_decimals:  base_decimals,
      quote_decimals: quote_decimals
    )

    token_pair.update!(current_price: new_price, price_updated_at: Time.current)

    token_pair.token_pair_prices.create!(price: new_price)
  end

  #def self.get_price(token_pair, sell_amount=DEFAULT_SELL_AMOUNT)
  #  base_token = token_pair.base_token
  #  quote_token = token_pair.quote_token

  #  EthersService.get_price(
  #    quote_token.contract_address, 
  #    base_token.contract_address, 
  #    quote_token.decimals, 
  #    base_token.decimals, 
  #    sell_amount, 
  #    ZERO_EX_API_KEY
  #  )
  #end

  # Phase 1: canonical price = TOKEN -> ETH for ~0.1 ETH notional
  def self.get_price(token_pair)
    base_token  = token_pair.base_token  # e.g. RUNNER
    quote_token = token_pair.quote_token # e.g. WETH

    # Decide how many base tokens to sell (approx 0.1 ETH worth)
    sell_amount_base_str =
      if token_pair.current_price.present?
        # current_price is ETH per base token
        # tokens ≈ 0.1 ETH / (ETH per token)
        est_tokens = DEFAULT_SELL_AMOUNT / token_pair.current_price

        est_tokens.round(base_token.decimals).to_s
        #est_tokens.to_s
      else
        # First tick: rough bootstrap using a fixed token amount.
        # On the next tick, we'll have a real current_price and switch to 0.1 ETH notional.
        "1000"
      end
 
    EthersService.get_price(
      base_token.contract_address,   # sellToken: TOKEN
      quote_token.contract_address,  # buyToken:  WETH
      base_token.decimals,
      quote_token.decimals,
      sell_amount_base_str,          # decimal string, e.g. "1500"
      ZERO_EX_API_KEY
    )
  end

  def self.eth_per_base_token(result, base_decimals:, quote_decimals:)
    sell_amount_wei = result["sellAmountWei"].to_d
    buy_amount_wei  = result["buyAmountWei"].to_d

    sell_human = sell_amount_wei / (10.to_d ** base_decimals)   # base token (e.g. RUNNER)
    buy_human  = buy_amount_wei  / (10.to_d ** quote_decimals)  # quote token (WETH/ETH)

    buy_human / sell_human
  end

  def self.get_uniswap_price(token_pair)
    provider_url = ProviderUrlService.get_provider_url(token_pair.chain.name)
    EthersService.get_token_price_from_pool(token_pair, provider_url)
  end

  def self.update_price_for_pair(token_pair)
    provider_url = ProviderUrlService.get_provider_url(token_pair.chain.name)
    
    if pool_stale?(token_pair)
      # If pool info is stale, call the full price function (which returns pool info too)
      result = EthersService.get_token_price(token_pair, provider_url)
      new_price = result["price"].to_d

      puts "Updating price for #{token_pair.base_token.symbol} from EthersService.get_token_price"
      puts "new_price: #{new_price.to_s}"

      token_pair.update!(
        current_price: new_price,
        price_updated_at: Time.current,
        pool_address: result["poolAddress"],
        fee_tier: result["feeTier"],
        pool_address_updated_at: Time.current
      )
      
      token_pair.token_pair_prices.create!(price: new_price)
    else
      # Otherwise, use the cached pool info to get an updated price
      new_price = EthersService.get_token_price_from_pool(token_pair, provider_url)

      puts "Updating price for #{token_pair.base_token.symbol} from EthersService.get_token_price_from_pool"
      puts "new_price: #{new_price.to_s}"

      token_pair.update!(
        current_price: new_price.to_d,
        price_updated_at: Time.current
      )

      token_pair.token_pair_prices.create!(price: new_price.to_d)
    end
  end

  def self.get_eth_price_in_usd(chain)
    return 0 if chain.nil?
    
    base_token = Token.find_by(chain: chain, symbol: 'USDC')
    quote_token = Token.find_by(chain: chain, symbol: 'WETH')
    token_pair = TokenPair.find_by(chain: chain, base_token: base_token, quote_token: quote_token)
    
    price = token_pair.latest_price
    1 / price  # Convert USDC/WETH to USD/ETH
  end

  private

  def self.provider_url_for(chain)
    @provider_urls ||= {}
    @provider_urls[chain.name] ||= ProviderUrlService.get_provider_url(chain.name)
  end

  def self.pool_stale?(token_pair)
    token_pair.pool_address_updated_at.nil? || token_pair.pool_address_updated_at < 1.day.ago
  end
end
