namespace :ethers_test do

  PROVIDER_URL = "https://base-mainnet.infura.io/v3/#{ENV['INFURA_API_KEY']}"

  desc "Get balance"
  task :get_balance, [:wallet] => :environment do |t, args|
    if args[:wallet].nil?
      raise ArgumentError, "Missing parameters!"
    end
    puts "wallet = #{args[:wallet]}"
    balance = EthersService.get_balance(args[:wallet], PROVIDER_URL)
    puts balance
  end

  desc "Get nonce"
  task :get_transaction_count, [:wallet] => :environment do |t, args|
    if args[:wallet].nil?
      raise ArgumentError, "Missing parameters!"
    end
    puts "wallet = #{args[:wallet]}"
    nonce = EthersService.get_transaction_count(args[:wallet], PROVIDER_URL)
    puts nonce
  end

  desc "Get token balance"
  task :get_token_balance, [:wallet, :token] => :environment do |t, args|
    if args[:wallet].nil? || args[:token].nil?
      raise ArgumentError, "Missing parameters!"
    end
    puts "wallet = #{args[:wallet]}"
    puts "token = #{args[:token]}"
    balance = EthersService.get_token_balance(
      args[:wallet], 
      args[:token],
      PROVIDER_URL
    )
    puts balance
  end
end
