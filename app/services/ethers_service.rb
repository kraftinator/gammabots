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
  
  #def self.swap(private_key, amount, token_in, token_out, provider_url)
  #  call_function('swap', private_key, amount, token_in, token_out, provider_url)
  #end

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

    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { success: false, error: "gas lookup failed: #{e.message}" }
    end

    tx_response = with_wallet_nonce_lock(wallet) do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function('sellWithMinAmount', wallet.private_key, base_token_amount, base_token, quote_token, base_token_decimals, quote_token_decimals, fee_tier, min_amount_out, provider_url, nonce, fees['maxFeePerGas'], fees['maxPriorityFeePerGas'])
        #if result["success"] && result["txHash"].present?
        #  increment_nonce(wallet.address)
        #end
        if result["bumpNonce"].to_s == "true"
          increment_nonce(wallet.address)
        end
        result
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end 
  end

  def self.clear_nonce(wallet, nonce_to_clear, provider_url)
    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { success: false, error: "gas lookup failed: #{e.message}" }
    end

    tx_response = with_wallet_nonce_lock(wallet) do
      begin
        result = call_function('clearNonce', wallet.private_key, nonce_to_clear, provider_url, fees['maxFeePerGas'], fees['maxPriorityFeePerGas'])
        if result['success'] || result['txHash'].present?
          reset_nonce(wallet.address)
        end
        result
      rescue StandardError => e
        Rails.logger.error("[EthersService.clear_nonce] failed to clear nonce #{nonce_to_clear}: #{e.message}")
        { success: false, error: e.message }
      end
    end
  end

=begin
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
=end

  def self.with_nonce_lock(address, chain_id, &block)
    lock_key = "eth_nonce_lock:#{chain_id}:#{address}"

    REDLOCK_CLIENT.lock!(
      lock_key,
      5_000,
      retry_count: 50,
      retry_delay: 100
    ) { yield }
  rescue Redlock::LockError
    raise "Could not acquire nonce lock for #{address} on chain #{chain_id}—please retry later"
  end

  def self.with_wallet_nonce_lock(wallet, &block)
    with_nonce_lock(wallet.address, wallet.chain_id, &block)
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
    
    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { success: false, error: "gas lookup failed: #{e.message}" }
    end
    
    tx_response = with_wallet_nonce_lock(wallet) do
      begin
        nonce = current_nonce(wallet.address, provider_url)
        result = call_function('buyWithMinAmount', wallet.private_key, quote_token_amount, quote_token, base_token, quote_token_decimals, base_token_decimals, fee_tier, min_amount_out, provider_url, nonce, fees['maxFeePerGas'], fees['maxPriorityFeePerGas'])
        #if result["success"] && result["txHash"].present?
        #  increment_nonce(wallet.address)
        #end
        if result["bumpNonce"].to_s == "true"
          increment_nonce(wallet.address)
        end
        result
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end

  def self.infinite_approve(wallet, token_address, spender_address, provider_url)
    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { success: false, error: "gas lookup failed: #{e.message}" }
    end

    tx_response = with_wallet_nonce_lock(wallet) do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function('infiniteApprove', wallet.private_key, token_address, provider_url, nonce, fees['maxFeePerGas'], fees['maxPriorityFeePerGas'], spender_address)
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

  def self.get_latest_nonce(address, provider_url)
    result = call_function('getTransactionCount', address, provider_url)
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

  def self.cached_nonce(address)
    key = "nonce:#{address}"
    $redis.get(key).to_i
  end

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

  def self.get_token_price_from_pool_with_fields(base_token_address, base_token_decimals, quote_token_address, quote_token_decimals, pool_address, provider_url)
    puts "Calling getPriceFromPool for #{base_token_address}"
    call_function(
      'getPriceFromPool', 
      base_token_address, 
      base_token_decimals, 
      quote_token_address, 
      quote_token_decimals,
      pool_address,
      provider_url
    )
  end

  #def self.get_max_amount_in(token_pair, provider_url)
  #  puts "Calling getMaxAmountIn for #{token_pair.base_token.symbol}"
  #  call_function(
  #    'getMaxAmountIn',
  #    token_pair.latest_price,
  #    token_pair.pool_address,
  #    token_pair.base_token.decimals,
  #    token_pair.quote_token.decimals,
  #    provider_url
  #  )
  #end

  # Not used
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

  def self.find_most_liquid_pool(token_0, token_1, provider_url)
    call_function('findMostLiquidPool', token_0, token_1, provider_url)
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

  def self.get_ETH_transfer_details(tx_hash, provider_url)
    call_function('getEthTransferDetails', tx_hash, provider_url)
  end

  def self.get_strategy_NFT_details(tx_hash, provider_url)
    call_function('getStrategyNftDetails', tx_hash, provider_url)
  end

  def self.get_transaction_receipt(tx_hash, wallet_address, token_pair, provider_url)
    # txHash,
    # poolAddress,
    # walletAddress,
    # tokenAAddress,
    # tokenADecimals,
    # tokenBAddress,
    # tokenBDecimals,
    # providerUrl
    base_token = token_pair.base_token
    quote_token = token_pair.quote_token
    call_function(
      'getNetSwapAmounts', 
      tx_hash,
      token_pair.pool_address,
      wallet_address,
      base_token.contract_address,
      base_token.decimals,
      quote_token.contract_address,
      quote_token.decimals,
      provider_url
    )
    #call_function(
    #  'getSwapAmounts', 
    #  tx_hash,
    #  token_pair.pool_address,
    #  token_pair.base_token.decimals,
    #  token_pair.quote_token.decimals,
    #  provider_url
    #)
  end

  def self.get_wrap_receipt(tx_hash, provider_url)
    call_function('getWrapReceipt', tx_hash, provider_url)
  end

  # Same as wrap receipt. Change name of JS function.
  def self.get_transfer_receipt(tx_hash, provider_url)
    call_function('getWrapReceipt', tx_hash, provider_url)
  end

  def self.get_wallet_address(private_key, provider_url)
    call_function('getWalletAddress', private_key, provider_url)
  end

  def self.get_gas_price(chain_id, provider_url)
    key = "gas_price:#{chain_id}"
    lock_key = "#{key}:lock"

    if (cached = $redis.get(key))
      return Integer(cached).to_s
    end

    if $redis.set(lock_key, "1", nx: true, ex: 1)
      begin
        price = get_gas_price_from_api(provider_url)
        $redis.set(key, price.to_s, ex: 5)   # cache for 5s
        return price.to_s
      ensure
        $redis.del(lock_key)
      end
    else
      # 3) Another process is fetching — wait briefly and retry
      sleep 0.05 until (cached = $redis.get(key))
      return Integer(cached).to_s
    end
  end

  def self.get_gas_fees(chain_id, provider_url)
    key = "gas_fees:#{chain_id}"
    if (cached = $redis.get(key))
      return JSON.parse(cached)
    end
  
    raw = get_gas_fees_from_api(provider_url)
    raw_json = raw.to_json
    $redis.set(key, raw_json, ex: 5)  # cache for 5s
    JSON.parse(raw_json)
  end
  
  def self.get_gas_fees_from_api(provider_url)
    call_function('getGasFees', provider_url)
  end

  def self.get_gas_price_from_api(provider_url)
    call_function('getGasPrice', provider_url)
  end

  def self.generate_wallet
    call_function('generateWallet')
  end

  def self.is_infinite_approval(private_key, token_address, spender_address, provider_url)
    call_function(
      'isInfiniteApproval',
      private_key,
      token_address,
      spender_address,
      provider_url
    )
  end

  def self.send_ETH(wallet, to_address, amount, provider_url)
    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { "success" => false, "error" => "gas lookup failed: #{e.message}" }
    end

    with_wallet_nonce_lock(wallet) do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        # privateKey,
        # toAddress,
        # amountEth,
        # providerUrl,
        # nonce,
        # maxFeePerGasString,
        # maxPriorityFeePerGasString
        result = call_function(
          'sendEth',
          wallet.private_key,
          to_address,
          amount,
          provider_url,
          nonce,
          fees['maxFeePerGas'],
          fees['maxPriorityFeePerGas']
        )

        if result['success'] && result['txHash'].present?
          increment_nonce(wallet.address)
        end

        result
      rescue StandardError => e
        { "success" => false, "error" => e.message, "nonce" => nonce }
      end
    end
  end

  def self.convert_WETH_to_ETH(wallet, provider_url, amount)
    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { "success" => false, "error" => "gas lookup failed: #{e.message}" }
    end

    with_wallet_nonce_lock(wallet) do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function(
          'unwrapWETH',
          wallet.private_key,
          provider_url,
          amount,
          nonce,
          fees['maxFeePerGas'],
          fees['maxPriorityFeePerGas']
        )

        if result['bumpNonce'].to_s == "true"
          increment_nonce(wallet.address)
        end

        result
      rescue StandardError => e
        { "success" => false, "error" => e.message, "nonce" => nonce }
      end
    end
  end

  #def self.convert_ETH_to_WETH(private_key, provider_url, amount, eth_reserve_percentage = 1)
  #  call_function('convertETHToWETH', private_key, provider_url, amount, eth_reserve_percentage)
  #end

  def self.convert_ETH_to_WETH(wallet, provider_url, amount, eth_reserve_percentage = 0)
    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { "success" => false, "error" => "gas lookup failed: #{e.message}" }
    end

    with_wallet_nonce_lock(wallet) do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function(
          #'convertETHToWETH',
          'wrapETH',
          wallet.private_key,
          provider_url,
          amount,
          eth_reserve_percentage,
          nonce,
          fees['maxFeePerGas'],
          fees['maxPriorityFeePerGas']
        )

        #if result['success'] && result['txHash'].present?
        if result['bumpNonce'].to_s == "true"
          increment_nonce(wallet.address)
        end

        result
      rescue StandardError => e
        { "success" => false, "error" => e.message, "nonce" => nonce }
      end
    end
  end

  def self.send_erc20(wallet, token_address, to_address, amount, decimals, provider_url)
    begin
      fees = get_gas_fees(wallet.chain_id, provider_url)
    rescue => e
      return { "success" => false, "error" => "gas lookup failed: #{e.message}" }
    end

    with_wallet_nonce_lock(wallet) do
      nonce = current_nonce(wallet.address, provider_url)
      begin
        result = call_function(
          'sendErc20',
          wallet.private_key,
          token_address,
          to_address,
          amount,
          decimals,
          provider_url,
          nonce,
          fees['maxFeePerGas'],
          fees['maxPriorityFeePerGas']
        )

        if result['success'] && result['txHash'].present?
          increment_nonce(wallet.address)
        end

        result
      rescue StandardError => e
        { "success" => false, "error" => e.message, "nonce" => nonce }
      end
    end

  end

  def self.current_block_number(provider_url)
    call_function('getCurrentBlockNumber', provider_url)
  end

  def self.get_swaps(wallet_address, last_processed_block, current_block, provider_url)
    puts "Fetching swaps for #{wallet_address} from block #{last_processed_block} to #{current_block}"
    call_function('getSwaps', wallet_address, last_processed_block, current_block, provider_url)
  end

  def self.last_processed_block_number(chain_id, provider_url)
    key = "last_block:#{chain_id}"

    unless $redis.exists?(key)
      current_block = current_block_number(provider_url)
      $redis.set(key, current_block)
    end

    $redis.get(key).to_i
  end

  def self.update_last_processed_block(chain_id, block_number)
    key = "last_block:#{chain_id}"
    $redis.set(key, block_number)
  end

  def self.get_0x_quote(
    sell_token,
    buy_token,
    amount,
    sell_token_decimals,
    wallet_address,
    zero_ex_api_key
  )
    call_function(
      'get0xQuote', 
      sell_token,
      buy_token,
      amount,
      sell_token_decimals,
      wallet_address,
      zero_ex_api_key
    )
  end

  def self.swap(wallet, sell_token, buy_token, sell_token_amount, sell_token_decimals, buy_token_decimals, max_slippage, zero_ex_api_key, provider_url, min_amount_out=0)
    tx_response = with_wallet_nonce_lock(wallet) do
      begin
        nonce = current_nonce(wallet.address, provider_url)
        result = call_function(
          'quoteAndSwap0x', 
          wallet.private_key, 
          sell_token, 
          buy_token,
          sell_token_amount,
          min_amount_out,
          sell_token_decimals,
          buy_token_decimals,
          wallet.address,
          zero_ex_api_key,
          provider_url,
          nonce,
          max_slippage,
          true
        )

        return result unless result["success"]  

        if result["bumpNonce"].to_s == "true"
          increment_nonce(wallet.address)
        end
        result
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end

  def self.read_swap_receipt_erc20(tx_hash, taker, sell_token, sell_token_decimals, buy_token, buy_token_decimals, provider_url)
    result = call_function(
      'readSwapReceiptERC20',
      provider_url,
      tx_hash,
      taker,
      sell_token,
      sell_token_decimals,
      buy_token,
      buy_token_decimals
    )
  end

  def self.validate_token(taker, token_address, token_decimals, zero_ex_api_key, provider_url)
    call_function('validateTokenPairWith0x', taker, token_address, token_decimals, provider_url, zero_ex_api_key)
  end

  def self.get_price(sell_token, buy_token, sell_token_decimals, buy_token_decimals, sell_token_amount, zero_ex_api_key)
    call_function('get0xPrice', sell_token, buy_token, sell_token_amount, sell_token_decimals, buy_token_decimals, zero_ex_api_key)
  end
end