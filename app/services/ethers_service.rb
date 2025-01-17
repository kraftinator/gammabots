require 'open3'

class EthersService
  NODE_SCRIPT_PATH = Rails.root.join('lib', 'node_scripts', 'ethers_script.js')

  def self.get_balance(address, provider_url)
    command = "node #{NODE_SCRIPT_PATH} #{address} #{provider_url}"
    stdout, stderr, status = Open3.capture3(command)

    raise "Error: #{stderr.strip}" unless status.success?

    stdout.strip # Return the balance
  end
end
