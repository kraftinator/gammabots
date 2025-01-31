namespace :bots do

  desc "Run bot"
  # Usage:
  # rake bots:run["1"]
  task :run, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    BotRunner.run(bot)
  end

  desc "Create bot"
  # Usage:
  # rake bots:create["DEGEN","0.0005","1","base_mainnet","1"]
  task :create, [:token, :amount, :strategy, :chain_name, :user_id] => :environment do |t, args|
    if args[:token].nil? || args[:amount].nil? || args[:strategy].nil? || args[:chain_name].nil? || args[:user_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    # Get Chain
    chain = Chain.find_by(name: args[:chain_name])
    unless chain
      raise ArgumentError, "Invalid chain"
    end

    # Get User
    user = User.find(args[:user_id])
    unless user
      raise ArgumentError, "Invalid user"
    end

    # Get amount
    amount = args[:amount].to_d

    # Get Token
    token = Token.find_by(chain: chain, symbol: args[:token])
    unless token
      raise ArgumentError, "Invalid token"
    end

    # Get Trading Pair
    quote_token = Token.find_by(chain: chain, symbol: 'WETH')
    token_pair = TokenPair.find_by(chain: chain, base_token: token, quote_token: quote_token)
    unless token_pair
      raise ArgumentError, "Invalid token pair"
    end

    bot = Bot.create(
      chain: chain,
      user: user,
      token_pair: token_pair,
      quote_token_amount: amount
    )

    puts "Bot Created: #{bot.id.to_s}"
  end

end