namespace :token_pairs do
  desc "Create token pair"
  # Usage:
  # rake token_pairs:create["base_mainnet","0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed","WETH"]
  task :create, [:chain_name, :base_token_address, :quote_token_symbol] => :environment do |t, args|
    if args[:chain_name].nil? || args[:base_token_address].nil?
      raise ArgumentError, "Missing parameters!"
    end

    # Get Chain
    chain = Chain.find_by(name: args[:chain_name])
    unless chain
      raise ArgumentError, "Invalid chain"
    end

    base_token_address = args[:base_token_address].downcase

    # Get Base Token
    puts "FLAG A"
    puts "chain = #{chain.name}"
    puts "base_token_address: #{base_token_address}"
    base_token = Token.find_by(chain: chain, contract_address: base_token_address)
    puts "base_token = #{base_token.inspect}"
    puts "FLAG B"
    unless base_token.present?
      puts "FLAG C"
      base_token = Token.create_from_contract_address(base_token_address, chain)
      puts "FLAG D"
      unless base_token
        puts "FLAG E"
        raise ArgumentError, "Token creation failed"
      end
    end

    # Create base token
    #base_token = Token.create_from_contract_address(base_token_address, chain)
    #unless base_token
    #  raise ArgumentError, "Token creation failed"
    #end

    # Get Quote Token
    quote_token_symbol = args[:quote_token_symbol] || "WETH"
    quote_token = Token.find_by(chain: chain, symbol: quote_token_symbol)
    unless quote_token
      raise ArgumentError, "Invalid quote token!"
    end

    # Create token pair
    token_pair = TokenPair.create!(
      chain: chain, 
      base_token: base_token, 
      quote_token: quote_token
    )
    unless token_pair
      raise ArgumentError, "Failed to create Token Pair"
    end

    token_pair.latest_price
    puts "Token Pair created: #{token_pair.name}"
  end
end