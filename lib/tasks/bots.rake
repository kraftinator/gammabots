include ActionView::Helpers::DateHelper

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

  desc "Create bot from service"
  # Usage:
  # rake bots:create_from_service["1","0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed","0.0005","4","base_mainnet"]
  task :create_from_service, [:user_id, :token_contract_address, :initial_amount, :strategy_token_id, :moving_avg_minutes, :chain_name] => :environment do |t, args|
    if args[:user_id].nil? || args[:token_contract_address].nil? || args[:initial_amount].nil? || args[:strategy_token_id].nil? || args[:moving_avg_minutes].nil? || args[:chain_name].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = CreateBotService.call(
      user_id: args[:user_id],
      token_contract_address: args[:token_contract_address],
      initial_amount: args[:initial_amount],
      strategy_token_id: args[:strategy_token_id],
      moving_avg_minutes: args[:moving_avg_minutes],
      chain_name: args[:chain_name]
    )

    puts "Bot Created: #{bot.id}"
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
    puts "id:          #{bot.id.to_s}"
    puts "user:        #{bot.user.id.to_s}"
    puts "chain:       #{bot.chain.name}"
    puts "active:      #{bot.active}"
    puts "token_pair:  #{bot.token_pair.name}"
    puts "strategy:    #{bot.strategy.nft_token_id.to_s}"
    puts "moving_avg:  #{bot.moving_avg_minutes.to_s} minutes"
    puts ""
    puts "initial_buy: #{bot.initial_buy_amount} #{symbol}"
    puts "\nHOLDINGS"
    puts "---------"
    puts "base_token_amount:  #{bot.base_token_amount} #{bot.token_pair.base_token.symbol}"
    puts "quote_token_amount: #{bot.quote_token_amount} #{symbol}"
    puts "\nSTRATEGY"
    puts "--------"
    puts "current_price:                        #{bot.token_pair.current_price.nil? ? '---' : "#{bot.token_pair.current_price} #{symbol}"}"
    puts "current_moving_avg:                   #{bot.token_pair.moving_average(bot.moving_avg_minutes).nil? ? '---' : "#{bot.token_pair.moving_average(bot.moving_avg_minutes)} #{symbol}"}"
    puts "longterm_moving_avg:                  #{bot.token_pair.moving_average(bot.moving_avg_minutes*2).nil? ? '---' : "#{bot.token_pair.moving_average(bot.moving_avg_minutes*2)} #{symbol}"}"
    puts ""
    puts "initial_buy_price:                    #{bot.initial_buy_price.nil? ? '---' : "#{bot.initial_buy_price} #{symbol}"}"
    puts "created_at_price:                     #{bot.created_at_price.nil? ? '---' : "#{bot.created_at_price} #{symbol}"}"
    puts "lowest_price_since_creation:          #{bot.lowest_price_since_creation.nil? ? '---' : "#{bot.lowest_price_since_creation} #{symbol}"}"
    puts "highest_price_since_initial_buy:      #{bot.highest_price_since_initial_buy.nil? ? '---' : "#{bot.highest_price_since_initial_buy} #{symbol}"}"
    puts "lowest_price_since_initial_buy:       #{bot.lowest_price_since_initial_buy.nil? ? '---' : "#{bot.lowest_price_since_initial_buy} #{symbol}"}"
    puts "highest_price_since_last_trade:       #{bot.highest_price_since_last_trade.nil? ? '---' : "#{bot.highest_price_since_last_trade} #{symbol}"}"
    puts "lowest_price_since_last_trade:        #{bot.lowest_price_since_last_trade.nil? ? '---' : "#{bot.lowest_price_since_last_trade} #{symbol}"}"
    puts "last_sell_price:                      #{bot.last_sell_price.nil? ? '---' : "#{bot.last_sell_price} #{symbol}"}" 
    puts ""
    puts "lowest_moving_avg_since_creation:     #{bot.lowest_moving_avg_since_creation.nil? ? '---' : "#{bot.lowest_moving_avg_since_creation} #{symbol}"}"
    puts "highest_moving_avg_since_initial_buy: #{bot.highest_moving_avg_since_initial_buy.nil? ? '---' : "#{bot.highest_moving_avg_since_initial_buy} #{symbol}"}"
    puts "lowest_moving_avg_since_initial_buy:  #{bot.lowest_moving_avg_since_initial_buy.nil? ? '---' : "#{bot.lowest_moving_avg_since_initial_buy} #{symbol}"}"
    puts "highest_moving_avg_since_last_trade:  #{bot.highest_moving_avg_since_last_trade.nil? ? '---' : "#{bot.highest_moving_avg_since_last_trade} #{symbol}"}"
    puts "lowest_moving_avg_since_last_trade:   #{bot.lowest_moving_avg_since_last_trade.nil? ? '---' : "#{bot.lowest_moving_avg_since_last_trade} #{symbol}"}"
    puts "\nTRADES"
    puts "---------"
    puts "buys:  #{bot.trades.where(trade_type: "buy", status: "completed").count}"
    puts "sells: #{bot.trades.where(trade_type: "sell", status: "completed").count}"
    puts ""
  end

  desc "Liquidate"
  # Usage:
  # rake bots:liquidate["2"]
  task :liquidate, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    trade = bot.liquidate
    if trade
      puts "Liquidated!: #{trade.id}"
    else
      puts "Failed to liquidate!"
    end
  end

  desc "Deactivate"
  # Usage:
  # rake bots:deactivate["2"]
  task :deactivate, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    bot.update!(active: false)
    puts "Deactivated!"
  end

  desc "List active bots"
  # Usage:
  # rake bots:list
  task :list => :environment do
    puts "\n== Active Bots (#{Bot.active.count}) =="
    puts "%-6s %-20s %-10s %15s %15s %9s %-6s %-20s" % ["ID", "Token", "Strategy", "Tokens", "Sold", "Initial", "Sells", "Created At"]
    puts "-" * 110  # Increased width to match all columns
    
    Bot.active.order(created_at: :asc).each do |bot|
      puts "%-6s %-20s %-10s %15s %15s %9.4f %-6s %-20s" % [
        bot.id,
        #bot.token_pair.try(:name).to_s[0...18],
        bot.token_pair.base_token.symbol[0...18],
        #bot.strategy.nft_token_id,
        "#{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes})",
        bot.base_token_amount.round(6).to_s,
        bot.sell_count > 0 ? bot.quote_token_amount.round(6).to_s : 0.0,
        bot.initial_buy_made? ? bot.initial_buy_amount : bot.quote_token_amount,
        bot.trades.where(trade_type: "sell", status: "completed").count,
        #bot.created_at.strftime('%Y-%m-%d %H:%M')
        "#{time_ago_in_words(bot.created_at) } ago"
      ]
    end
  end

  desc "List recently retired bots"
  # Usage:
  # rake bots:list_retired
  task :list_retired => :environment do
    bots = Bot.inactive.where(created_at: 1.week.ago..Time.current).order(created_at: :asc).select { |bot| bot.trades.where(trade_type: "sell").any? }
    puts "\n== Retired Bots (#{bots.size}) =="
    puts "%-6s %-20s %-10s %15s %15s %9s %-6s %-20s" % ["ID", "Token", "Strategy", "Tokens", "Sold", "Initial", "Sells", "Created At"]
    puts "-" * 110  # Increased width to match all columns
    
    bots.each do |bot|
      puts "%-6s %-20s %-10s %15s %15s %9.4f %-6s %-20s" % [
        bot.id,
        #bot.token_pair.try(:name).to_s[0...18],
        bot.token_pair.base_token.symbol[0...18],
        #bot.strategy.nft_token_id,
        "#{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes})",
        bot.base_token_amount.round(6).to_s,
        bot.sell_count > 0 ? bot.quote_token_amount.round(6).to_s : 0.0,
        bot.initial_buy_made? ? bot.initial_buy_amount : bot.quote_token_amount,
        bot.trades.where(trade_type: "sell", status: "completed").count,
        #bot.created_at.strftime('%Y-%m-%d %H:%M')
        "#{time_ago_in_words(bot.created_at) } ago"
      ]
    end
  end

  desc "List all retired bots"
  # Usage:
  # rake bots:list_retired_all
  task :list_retired_all => :environment do
    bots = Bot.inactive.order(created_at: :asc).select { |bot| bot.trades.where(trade_type: "sell").any? }
    puts "\n== Retired Bots (#{bots.size}) =="
    puts "%-6s %-20s %-10s %15s %15s %9s %-6s %-20s" % ["ID", "Token", "Strategy", "Tokens", "Sold", "Initial", "Sells", "Created At"]
    puts "-" * 110  # Increased width to match all columns
    
    bots.each do |bot|
      puts "%-6s %-20s %-10s %15s %15s %9.4f %-6s %-20s" % [
        bot.id,
        #bot.token_pair.try(:name).to_s[0...18],
        bot.token_pair.base_token.symbol[0...18],
        #bot.strategy.nft_token_id,
        "#{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes})",
        bot.base_token_amount.round(6).to_s,
        bot.sell_count > 0 ? bot.quote_token_amount.round(6).to_s : 0.0,
        bot.initial_buy_made? ? bot.initial_buy_amount : bot.quote_token_amount,
        bot.trades.where(trade_type: "sell", status: "completed").count,
        #bot.created_at.strftime('%Y-%m-%d %H:%M')
        "#{time_ago_in_words(bot.created_at) } ago"
      ]
    end
  end

  desc "Stats"
  # Usage:
  # rake bots:stats["2"]
  task :stats, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    #symbol = bot.token_pair.quote_token.symbol
    symbol_base  = bot.token_pair.base_token.symbol
    symbol_quote = bot.token_pair.quote_token.symbol

    vars = bot.strategy_variables

    puts "\nHOLDINGS"
    puts "---------"
    puts "initial_buy_amount:  #{bot.initial_buy_amount} #{symbol_quote}"
    puts "base_token_amount:   #{bot.base_token_amount} #{symbol_base}"
    puts "quote_token_amount:  #{bot.quote_token_amount} #{symbol_quote}"


    puts "\nSTRATEGY VARIABLES"
    puts "---------"
    puts "bta (base_token_amount):                    #{vars[:bta]} #{bot.token_pair.base_token.symbol}"
    puts "bcn (buy_count):                            #{vars[:bcn]}"
    puts "scn (sell_count):                           #{vars[:scn]}"
    puts "mam (moving_avg_minutes):                   #{vars[:mam]}"
    puts ""
    puts "cpr (current_price):                        #{vars[:cpr].nil? ? '---' : "#{vars[:cpr]} #{symbol_quote}"}"
    puts "cma (current_moving_avg):                   #{vars[:cma].nan? ? '---' : "#{vars[:cma]} #{symbol_quote}"}" 
    puts "lma (longterm_moving_avg):                  #{vars[:lma].nan? ? '---' : "#{vars[:lma]} #{symbol_quote}"}"
    puts ""
    puts "ibp (initial_buy_price):                    #{vars[:ibp].nil? ? '---' : "#{vars[:ibp]} #{symbol_quote}"}"
    puts "lps (lowest_price_since_creation):          #{vars[:lps].nil? ? '---' : "#{vars[:lps]} #{symbol_quote}"}"
    puts "hip (highest_price_since_initial_buy):      #{vars[:hip].nil? ? '---' : "#{vars[:hip]} #{symbol_quote}"}"
    puts "lip (lowest_price_since_initial_buy):       #{vars[:lip].nil? ? '---' : "#{vars[:lip]} #{symbol_quote}"}"
    puts "hlt (highest_price_since_last_trade):       #{vars[:hlt].nil? ? '---' : "#{vars[:hlt]} #{symbol_quote}"}"
    puts "llt (lowest_price_since_last_trade):        #{vars[:llt].nil? ? '---' : "#{vars[:llt]} #{symbol_quote}"}"  
    puts ""
    puts "lmc (lowest_moving_avg_since_creation):     #{vars[:lmc].nan? ? '---' : "#{vars[:lmc]} #{symbol_quote}"}"  
    puts "lmi (lowest_moving_avg_since_initial_buy):  #{vars[:lmi].nil? ? '---' : "#{vars[:lmi]} #{symbol_quote}"}"
    puts "hma (highest_moving_avg_since_initial_buy): #{vars[:hma].nil? ? '---' : "#{vars[:hma]} #{symbol_quote}"}"
    puts "lmt (lowest_moving_avg_since_last_trade):   #{vars[:lmt].nil? ? '---' : "#{vars[:lmt]} #{symbol_quote}"}"
    puts "hmt (highest_moving_avg_since_last_trade):  #{vars[:hmt].nil? ? '---' : "#{vars[:hmt]} #{symbol_quote}"}"
    puts ""
    puts "lsp (last_sell_price):                      #{vars[:lsp].nil? ? '---' : "#{vars[:lsp]} #{symbol_quote}"}"
    puts ""
    puts "crt (created_at):                           #{vars[:crt]}"
    puts "lba (last_buy_at):                          #{vars[:lba].nil? ? '---' : "#{vars[:lba]}"}"
    puts "lta (last_trade_at):                        #{vars[:lta].nil? ? '---' : "#{vars[:lta]}"}"
    
    puts "\nTRADES"
    puts "---------"
    bot.trades.order(:id).each do |trade|
      puts "Trade ##{trade.id} (#{trade.trade_type.upcase}):"
      puts "  Price:         #{trade.price} #{symbol_quote}"
      puts "  Amount In:     #{trade.amount_in} #{symbol_quote}"
      puts "  Amount Out:    #{trade.amount_out} #{symbol_base}"
      puts "  Executed At:   #{trade.executed_at}"
      puts "  Confirmed At:  #{trade.confirmed_at || '---'}"
      puts "  Block Number:  #{trade.block_number}"
      puts "  Gas Used:      #{trade.gas_used}"
      puts "  Status:        #{trade.status}"
      puts ""
    end  

    strategy = JSON.parse(bot.strategy_json)

    puts "\nSTRATEGY"
    puts "--------"
    strategy.each_with_index do |step,index|
      puts "#{index+1}: #{step}"
    end

    puts ""
  end
end