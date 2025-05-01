require 'open3'
require 'json'

class EthersService
  NODE_SCRIPT_PATH = Rails.root.join('lib', 'node_scripts', 'ethers_adapter.js')

  def self.call_function(function_name, *args)
    command = ["node", NODE_SCRIPT_PATH.to_s, function_name, *args].join(' ')
    stdout, stderr, status = Open3.capture3(command)

    if status.success?
      response = JSON.parse(stdout)
      return response['result'] if response['success']

      raise "Error from Node script: #{response['error']}"
    else
      raise "Node script execution failed: #{stderr.strip}"
    end
  end

  def self.get_balance(address, provider_url)
    call_function('getBalance', address, provider_url)
  end

  def self.get_transaction_count(address, provider_url)
    call_function('getTransactionCount', address, provider_url)
  end

  def self.get_token_balance(wallet_address, token_address, provider_url)
    call_function('getTokenBalance', wallet_address, token_address, provider_url) 
  end

  def self.get_token_details(token_address, provider_url)
    call_function('getTokenDetails', token_address, provider_url) 
  end

  def self.get_quote(token_in, token_out, fee_tier, amount_in, token_in_decimals, token_out_decimals, provider_url)
    call_function('getQuote', token_in, token_out, fee_tier, amount_in, token_in_decimals, token_out_decimals, provider_url)
  end

  def self.get_sell_quote(token_pair, amount_in, provider_url)
    call_function(
      'getQuote',
      token_pair.base_token.contract_address,
      token_pair.quote_token.contract_address,
      token_pair.fee_tier,
      amount_in,
      token_pair.base_token.decimals,
      token_pair.quote_token.decimals,
      provider_url
    )
  end
  
  def self.swap(private_key, amount, token_in, token_out, provider_url)
    call_function('swap', private_key, amount, token_in, token_out, provider_url)
  end

  def self.buy(private_key, quote_token_amount, base_token, quote_token, quote_token_decimals, fee_tier, provider_url)
    call_function('buy', private_key, quote_token_amount, base_token, quote_token, quote_token_decimals, fee_tier, provider_url)
  end

  def self.sell(private_key, base_token_amount, base_token, quote_token, base_token_decimals, fee_tier, provider_url)
    call_function('sell', private_key, base_token_amount, base_token, quote_token, base_token_decimals, fee_tier, provider_url)
  end

  def self.sell_with_min_amount(wallet, base_token_amount, base_token, quote_token, base_token_decimals, quote_token_decimals, fee_tier, min_amount_out, provider_url)
    sim = quote_meets_minimum(
      base_token,
      quote_token,
      fee_tier,
      base_token_amount,
      base_token_decimals,
      quote_token_decimals,
      min_amount_out,
      provider_url
    )

    return { success: false, error: sim['error'] } unless sim['success']
    return { success: false, quote: sim['quoteRaw'], min_amount_out:  sim['minAmountOutRaw'] } unless sim['valid']

    tx_response = with_nonce_lock do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function('sellWithMinAmount', wallet.private_key, base_token_amount, base_token, quote_token, base_token_decimals, quote_token_decimals, fee_tier, min_amount_out, provider_url, nonce)
        if result["success"] && result["txHash"].present?
          increment_nonce(wallet.address)
        end
        result
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end 
  end

  def self.with_nonce_lock(&block)
    REDLOCK_CLIENT.lock!(
      "eth_nonce_lock",   # lock key
      2_000,              # TTL in ms
      retry_count: 10,    # try ~1s
      retry_delay: 100    # ms between tries
    ) { yield }
  rescue Redlock::LockError
    raise "Could not acquire nonce lock—please retry later"
  end

  def self.buy_with_min_amount(wallet, quote_token_amount, quote_token, base_token, quote_token_decimals, base_token_decimals, fee_tier, min_amount_out, provider_url)
    sim = quote_meets_minimum(
      quote_token,
      base_token,
      fee_tier,
      quote_token_amount,
      quote_token_decimals,
      base_token_decimals,
      min_amount_out,
      provider_url
    )

    return { success: false, error: sim['error'] } unless sim['success']  
    return { success: false, quote: sim['quoteRaw'], min_amount_out:  sim['minAmountOutRaw'] } unless sim['valid']

    tx_response = with_nonce_lock do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function('buyWithMinAmount', wallet.private_key, quote_token_amount, quote_token, base_token, quote_token_decimals, base_token_decimals, fee_tier, min_amount_out, provider_url, nonce)
        if result["success"] && result["txHash"].present?
          increment_nonce(wallet.address)
        end
        result
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end

  def self.infinite_approve(wallet, token_address, provider_url)
    tx_response = with_nonce_lock do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function('infiniteApprove', wallet.private_key, token_address, provider_url, nonce)
        if result["success"] && result["txHash"].present?
          increment_nonce(wallet.address)
        end
        result
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end

  def self.current_nonce(address, provider_url)
    key = "nonce:#{address}"

    unless $redis.exists?(key)
      pending_nonce = get_pending_nonce(address, provider_url)
      $redis.set(key, pending_nonce)
    end

    $redis.get(key).to_i
  end

  def self.get_pending_nonce(address, provider_url)
    result = call_function('getPendingNonce', address, provider_url)
    result.to_i
  end

  def self.increment_nonce(address)
    key = "nonce:#{address}"
    $redis.incr(key)
  end

  def self.decrement_nonce(address)
    key = "nonce:#{address}"
    $redis.decr(key)
  end

  def self.reset_nonce(address)
    key = "nonce:#{address}"
    $redis.del(key)
  end

  def self.get_nonce(address)
    key = "nonce:#{address}"
    $redis.get(key)
  end

=begin
  def self.buy_with_min_amount(wallet, quote_token_amount, quote_token, base_token, quote_token_decimals, base_token_decimals, fee_tier, min_amount_out, provider_url)
    sim = quote_meets_minimum(
      quote_token,
      base_token,
      fee_tier,
      quote_token_amount,
      quote_token_decimals,
      base_token_decimals,
      min_amount_out,
      provider_url
    )

    # abort if JS itself errored
    unless sim['success']
      return { success: false, error: sim['error'] }
    end

    # abort if the quote was too low
    unless sim['valid']
      return {
        success: false,
        quote:           sim['quoteRaw'],
        min_amount_out:  sim['minAmountOutRaw']
      }
    end

    nonce = allocate_nonce(wallet.address, provider_url)

    puts "Calling buyWithMinAmount with params: " \
                    "quote_token_amount=#{quote_token_amount}, " \
                    "quote_token=#{quote_token}, " \
                    "base_token=#{base_token}, " \
                    "quote_token_decimals=#{quote_token_decimals}, " \
                    "base_token_decimals=#{base_token_decimals}, " \
                    "fee_tier=#{fee_tier}, " \
                    "min_amount_out=#{min_amount_out}, " \
                    "nonce=#{nonce}"
    
    call_function('buyWithMinAmount', wallet.private_key, quote_token_amount, quote_token, base_token, quote_token_decimals, base_token_decimals, fee_tier, min_amount_out, provider_url, nonce)
  end
=end
  def self.quote_meets_minimum(quote_token, base_token, fee_tier, quote_token_amount, quote_token_decimals, base_token_decimals, min_amount_out, provider_url)
    call_function('quoteMeetsMinimum', quote_token, base_token, fee_tier, quote_token_amount, quote_token_decimals, base_token_decimals, min_amount_out, provider_url)
  end

  def self.get_token_price_from_pool(token_pair, provider_url)
    puts "Calling getPriceFromPool for #{token_pair.base_token.symbol}"
    call_function(
      'getPriceFromPool', 
      token_pair.base_token.contract_address, 
      token_pair.base_token.decimals, 
      token_pair.quote_token.contract_address, 
      token_pair.quote_token.decimals,
      token_pair.pool_address,
      provider_url
    )
  end

  def self.get_max_amount_in(token_pair, provider_url)
    puts "Calling getMaxAmountIn for #{token_pair.base_token.symbol}"
    call_function(
      'getMaxAmountIn',
      token_pair.latest_price,
      token_pair.pool_address,
      token_pair.base_token.decimals,
      token_pair.quote_token.decimals,
      provider_url
    )
  end

  def self.get_pool_data(token_pair, provider_url)
    puts "Calling getPoolData for #{token_pair.base_token.symbol}"
    call_function(
      'getPoolData',
      token_pair.base_token.contract_address,
      token_pair.base_token.decimals,
      token_pair.quote_token.contract_address,
      token_pair.quote_token.decimals,
      token_pair.pool_address,
      provider_url
    )
  end

  def self.get_token_price(token_pair, provider_url)
    puts "Calling getTokenPrice for #{token_pair.base_token.symbol}"
    call_function(
      'getTokenPrice', 
      token_pair.base_token.contract_address, 
      token_pair.base_token.decimals, 
      token_pair.quote_token.contract_address, 
      token_pair.quote_token.decimals, 
      provider_url
    )
  end

  def self.get_token_price_with_params(token_0, token_0_decimals, token_1, token_1_decimals, provider_url)
    call_function('getTokenPrice', token_0, token_0_decimals, token_1, token_1_decimals, provider_url)
  end

  #def self.get_transaction_receipt(tx_hash, decimals, provider_url)
  #  call_function('getTransactionReceipt', tx_hash, decimals, provider_url)
  #end

  # getSwapAmounts(txHash, poolAddress, decimals0, decimals1, providerUrl)
  def self.get_transaction_receipt(tx_hash, token_pair, provider_url)
    call_function(
      'getSwapAmounts', 
      tx_hash,
      token_pair.pool_address,
      token_pair.base_token.decimals,
      token_pair.quote_token.decimals,
      provider_url
    )
  end

  def self.get_wallet_address(private_key, provider_url)
    call_function('getWalletAddress', private_key, provider_url)
  end

  def self.generate_wallet
    call_function('generateWallet')
  end

  def self.convert_ETH_to_WETH(private_key, provider_url, amount, eth_reserve_percentage = 1)
    call_function('convertETHToWETH', private_key, provider_url, amount, eth_reserve_percentage)
  end

  def self.convert_WETH_to_ETH(private_key, provider_url, amount)
    call_function('convertWETHToETH', private_key, provider_url, amount)
  end

  def self.is_infinite_approval(private_key, token_address, provider_url)
    call_function(
      'isInfiniteApproval',
      private_key,
      token_address,
      provider_url
    )
  end

  def self.delete_nonce(address)
    key = "nonce:#{address}"
    $redis.del(key)
  end

  def self.allocate_nonce(address, provider_url)
    key = "nonce:#{address}"
    $redis.setnx(key, get_pending_nonce(address, provider_url))
    new_val = $redis.incr(key)
    return new_val - 1
  end
end