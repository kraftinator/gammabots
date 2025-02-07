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
  # rake bots:create["DEGEN","0.0005","4","base_mainnet","1"]
  task :create, [:token, :amount, :strategy_id, :chain_name, :user_id] => :environment do |t, args|
    if args[:token].nil? || args[:amount].nil? || args[:strategy_id].nil? || args[:chain_name].nil? || args[:user_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    # Get Chain
    chain = Chain.find_by(name: args[:chain_name])
    unless chain
      raise ArgumentError, "Invalid chain"
    end

    # Get Strategy
    strategy = Strategy.find(args[:strategy_id])
    unless strategy
      raise ArgumentError, "Invalid strategy"
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
      strategy: strategy,
      user: user,
      token_pair: token_pair,
      quote_token_amount: amount
    )

    puts "Bot Created: #{bot.id.to_s}"
  end

  desc "Show prices"
  # Usage:
  # rake bots:show_prices["2"]
  task :show_prices, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    symbol = bot.token_pair.quote_token.symbol
    puts "initial_buy_price:               #{bot.initial_buy_price} #{symbol}"
    puts "highest_price_since_initial_buy: #{bot.highest_price_since_initial_buy} #{symbol}"
    puts "lowest_price_since_initial_buy:  #{bot.lowest_price_since_initial_buy} #{symbol}"
    puts "highest_price_since_last_trade:  #{bot.highest_price_since_last_trade} #{symbol}"
    puts "lowest_price_since_last_trade:   #{bot.lowest_price_since_last_trade} #{symbol}"
  end

  desc "Show"
  # Usage:
  # rake bots:show["2"]
  task :show, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    symbol = bot.token_pair.quote_token.symbol
    puts "\nBASIC"
    puts "-----"
    puts "id:         #{bot.id.to_s}"
    puts "user:       #{bot.user.id.to_s}"
    puts "chain:      #{bot.chain.name}"
    puts "active:     #{bot.active}"
    puts "token_pair: #{bot.token_pair.name}"
    puts "strategy:   #{bot.strategy.id.to_s}"
    puts "\nHOLDINGS"
    puts "---------"
    puts "base_token_amount:  #{bot.base_token_amount} #{bot.token_pair.base_token.symbol}"
    puts "quote_token_amount: #{bot.quote_token_amount} #{symbol}"
    puts "\nSTRATEGY"
    puts "--------"
    puts "initial_buy_price:               #{bot.initial_buy_price} #{symbol}"
    puts "highest_price_since_initial_buy: #{bot.highest_price_since_initial_buy} #{symbol}"
    puts "lowest_price_since_initial_buy:  #{bot.lowest_price_since_initial_buy} #{symbol}"
    puts "highest_price_since_last_trade:  #{bot.highest_price_since_last_trade} #{symbol}"
    puts "lowest_price_since_last_trade:   #{bot.lowest_price_since_last_trade} #{symbol}"
    puts ""
  end
end