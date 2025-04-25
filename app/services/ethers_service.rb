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

  def self.get_quote_with_params(token_in, token_out, fee_tier, amount_in, token_in_decimals, token_out_decimals, provider_url)
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

  def self.sell_with_min_amount(private_key, base_token_amount, base_token, quote_token, base_token_decimals, quote_token_decimals, fee_tier, min_amount_out, provider_url)
    puts "Calling sellWithMinAmount with params: " \
                    "base_token_amount=#{base_token_amount}, " \
                    "base_token=#{base_token}, " \
                    "quote_token=#{quote_token}, " \
                    "base_token_decimals=#{base_token_decimals}, " \
                    "quote_token_decimals=#{quote_token_decimals}, " \
                    "fee_tier=#{fee_tier}, " \
                    "min_amount_out=#{min_amount_out}"

    call_function('sellWithMinAmount', private_key, base_token_amount, base_token, quote_token, base_token_decimals, quote_token_decimals, fee_tier, min_amount_out, provider_url)
  end

  def self.buy_with_min_amount(private_key, quote_token_amount, quote_token, base_token, quote_token_decimals, base_token_decimals, fee_tier, min_amount_out, provider_url)
    puts "Calling buyWithMinAmount with params: " \
                    "quote_token_amount=#{quote_token_amount}, " \
                    "quote_token=#{quote_token}, " \
                    "base_token=#{base_token}, " \
                    "quote_token_decimals=#{quote_token_decimals}, " \
                    "base_token_decimals=#{base_token_decimals}, " \
                    "fee_tier=#{fee_tier}, " \
                    "min_amount_out=#{min_amount_out}"
    call_function('buyWithMinAmount', private_key, quote_token_amount, quote_token, base_token, quote_token_decimals, base_token_decimals, fee_tier, min_amount_out, provider_url)
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

  def self.infinite_approve(private_key, token_address, provider_url)
    call_function(
      'infiniteApprove',
      private_key,
      token_address,
      provider_url
    )
  end

  def self.is_infinite_approval(private_key, token_address, provider_url)
    call_function(
      'isInfiniteApproval',
      private_key,
      token_address,
      provider_url
    )
  end
end