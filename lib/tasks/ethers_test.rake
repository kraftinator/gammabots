namespace :ethers_test do

  PRIVATE_KEY = ENV['PRIVATE_KEY']
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

  desc "Swap"
  task :swap, [:amount, :token_in, :token_out] => :environment do |t, args|
    if args[:amount].nil? || args[:token_in].nil? || args[:token_out].nil?
      raise ArgumentError, "Missing parameters!"
    end

    puts "amount = #{args[:amount]}"
    puts "token_in = #{args[:token_in]}"
    puts "token_out = #{args[:token_out]}"
    
    result = EthersService.swap(
      PRIVATE_KEY,
      args[:amount], 
      args[:token_in],
      args[:token_out],
      PROVIDER_URL
    )
    puts result
  end
end
