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
end
