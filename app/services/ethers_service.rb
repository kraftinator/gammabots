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
end