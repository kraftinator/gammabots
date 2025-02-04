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

  def self.swap(private_key, amount, token_in, token_out, provider_url)
    call_function('swap', private_key, amount, token_in, token_out, provider_url)
  end

  def self.buy(private_key, quote_token_amount, base_token, quote_token, quote_token_decimals, provider_url)
    call_function('buy', private_key, quote_token_amount, base_token, quote_token, quote_token_decimals, provider_url)
  end

  def self.sell(private_key, base_token_amount, base_token, quote_token, base_token_decimals, provider_url)
    call_function('sell', private_key, base_token_amount, base_token, quote_token, base_token_decimals, provider_url)
  end  

  def self.get_token_price(token_pair, provider_url)
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

  def self.get_transaction_receipt(tx_hash, decimals, provider_url)
    call_function('getTransactionReceipt', tx_hash, decimals, provider_url)
  end
end