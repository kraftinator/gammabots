namespace :ethers_test do

  desc "Get balance"
  task :get_balance, [:wallet] => :environment do |t, args|
    if args[:wallet].nil?
      raise ArgumentError, "Missing parameters!"
    end
    puts "wallet = #{args[:wallet]}"
    infura_api_key = ENV['INFURA_API_KEY']
    balance = EthersService.get_balance(args[:wallet], "https://base-mainnet.infura.io/v3/#{infura_api_key}")
    puts balance
  end

  desc "Get nonce"
  task :get_transaction_count, [:wallet] => :environment do |t, args|
    if args[:wallet].nil?
      raise ArgumentError, "Missing parameters!"
    end
    puts "wallet = #{args[:wallet]}"
    infura_api_key = ENV['INFURA_API_KEY']
    nonce = EthersService.get_transaction_count(args[:wallet], "https://base-mainnet.infura.io/v3/#{infura_api_key}")
    puts nonce
  end

  desc "Get token balance"
  task :get_token_balance, [:wallet, :token] => :environment do |t, args|
    if args[:wallet].nil? || args[:token].nil?
      raise ArgumentError, "Missing parameters!"
    end
    puts "wallet = #{args[:wallet]}"
    puts "token = #{args[:token]}"
    infura_api_key = ENV['INFURA_API_KEY']
    balance = EthersService.get_token_balance(
      args[:wallet], 
      args[:token],
      "https://base-mainnet.infura.io/v3/#{infura_api_key}"  
    )
    puts balance
  end
end
