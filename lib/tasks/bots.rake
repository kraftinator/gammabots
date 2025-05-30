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

    bot.deactivate
    puts "Deactivated!"
  end

  desc "Activate"
  # Usage:
  # rake bots:Activate["2"]
  task :activate, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    bot.activate
    puts "Activated!"
  end

  desc "List recently retired bots"
  task :list_retired, [:sort_by] => :environment do |t, args|
    # default to sorting by last action
    args.with_defaults(sort_by: 'last_action')
    sort_key = args[:sort_by]

    bots = Bot.inactive
              .joins(:trades)
              .where(
                created_at: 1.week.ago..Time.current,
                #created_at: 2.days.ago..Time.current,
                trades:      { status: 'completed' }
              )
              .distinct
              .to_a

    bots = case sort_key
           when 'profit'
             bots.sort_by(&:profit_percentage).reverse
           else
             bots.sort_by(&:last_action_at).reverse
           end

    label = sort_key == 'profit' ? 'profit %' : 'last action'
    puts "\n== Recently Retired Bots (#{bots.count}) — sorted by #{label} =="
    list_bots(bots)
  end

  desc "List all retired bots"
  task :list_retired_all, [:sort_by] => :environment do |t, args|
    # default to sorting by last action
    args.with_defaults(sort_by: 'last_action')
    sort_key = args[:sort_by]

    bots = Bot.inactive
              .joins(:trades)
              .where(trades: { status: 'completed' })
              .distinct
              .to_a

    bots = case sort_key
           when 'profit'
             bots.sort_by(&:profit_percentage).reverse
           else
             bots.sort_by(&:last_action_at).reverse
           end

    label = sort_key == 'profit' ? 'profit %' : 'last action'
    puts "\n== All Retired Bots (#{bots.count}) — sorted by #{label} =="
    list_bots(bots)
  end

  # Usage:
  # rake bots:prices["2"]
  task :prices, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    prices = bot.token_pair.token_pair_prices.order(created_at: :asc)
    puts "\nPRICES (#{bot.token_pair.name})"
    puts "---------"

    prices.each { |p| puts "#{p.created_at} - #{p.price.to_s}" }
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

    symbol_base  = bot.token_pair.base_token.symbol
    symbol_quote = bot.token_pair.quote_token.symbol

    vars = bot.latest_strategy_variables
    cycle = bot.current_cycle

    puts "\n//////////////////////////////////////////"
    puts "BOT ##{bot.id} (#{bot.token_pair.name})"
    puts "//////////////////////////////////////////"

    puts "\nHOLDINGS"
    puts "---------"
    puts "initial_buy_amount:  #{bot.initial_buy_amount} #{symbol_quote}"
    puts "base_token_amount:   #{bot.latest_cycle.base_token_amount} #{symbol_base}"
    puts "quote_token_amount:  #{bot.latest_cycle.quote_token_amount} #{symbol_quote}"

    puts "\nSTRATEGY VARIABLES"
    puts "---------"
    puts "bta (base_token_amount):                    #{vars[:bta]} #{bot.token_pair.base_token.symbol}"
    puts "bcn (buy_count):                            #{vars[:bcn]}"
    puts "scn (sell_count):                           #{vars[:scn]}"
    puts "mam (moving_avg_minutes):                   #{vars[:mam]}"
    puts ""
    puts "vst (short_term_volatility):                #{vars[:vst].nan? ? '---' : format('%.5f', vars[:vst])}"
    puts "vlt (long_term_volatility):                 #{vars[:vlt].nan? ? '---' : format('%.5f', vars[:vlt])}"
    puts ""
    puts "cpr (current_price):                        #{vars[:cpr].nil? ? '---' : "#{vars[:cpr]} #{symbol_quote}"}"
    puts "ppr (previous_price):                       #{vars[:ppr].nil? ? '---' : "#{vars[:ppr]} #{symbol_quote}"}"
    puts "cma (current_moving_avg):                   #{vars[:cma].nan? ? '---' : format('%.18f %s', vars[:cma], symbol_quote)}"
    puts "lma (longterm_moving_avg):                  #{vars[:lma].nan? ? '---' : format('%.18f %s', vars[:lma], symbol_quote)}"
    puts "rhi (rolling_high):                         #{vars[:rhi].nan? ? '---' : format('%.18f %s', vars[:rhi], symbol_quote)}"
    puts ""
    puts "ibp (initial_buy_price):                    #{vars[:ibp].nil? ? '---' : "#{vars[:ibp]} #{symbol_quote}"}"
    puts "cap (created_at_price):                     #{cycle.created_at_price.nil? ? '---' : "#{cycle.created_at_price} #{symbol_quote}"}"
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
      puts "  Amount In:     #{trade.amount_in.nil? ? '---' : "#{trade.amount_in} #{trade.buy? ? symbol_quote : symbol_base}"}"
      puts "  Amount Out:    #{trade.amount_out.nil? ? '---' : "#{trade.amount_out} #{trade.sell? ? symbol_quote : symbol_base}"}"

      puts "  Executed At:   #{trade.executed_at}"
      puts "  Confirmed At:  #{trade.confirmed_at || '---'}"
      puts "  Tx Hash:       #{trade.tx_hash}"
      puts "  Nonce:         #{trade.nonce}"
      puts "  Block Number:  #{trade.block_number}"
      puts "  Gas Used:      #{trade.gas_used}"
      puts "  Status:        #{trade.status}"
      puts "  Cycle:         #{trade.bot_cycle_id}"
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

  desc "Current Cycle"
  # Usage:
  # rake bots:current_cycle[2]
  task :current_cycle, [:bot_id] => :environment do |_t, args|
    bot_id = args[:bot_id]
    raise ArgumentError, "Missing bot_id" unless bot_id

    bot = Bot.find_by(id: bot_id)
    raise ArgumentError, "Invalid bot_id: #{bot_id}" unless bot

    symbol_base  = bot.token_pair.base_token.symbol
    #symbol_quote = bot.token_pair.quote_token.symbol
    symbol_quote = 'ETH'

    vars = bot.latest_strategy_variables
    cycle = bot.current_cycle

    puts "\n== Current Cycle for Bot ##{bot.id} - Strategy: #{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes}) =="
    puts "-" * 75

    puts "bta (base_token_amount):                    #{vars[:bta]} #{bot.token_pair.base_token.symbol}"
    puts "bcn (buy_count):                            #{vars[:bcn]}"
    puts "scn (sell_count):                           #{vars[:scn]}"
    puts "mam (moving_avg_minutes):                   #{vars[:mam]}"
    puts ""
    
    puts "lcp (previous_cycle_profit):                #{vars[:lcp].nil? ? '---' : format('%.5f', vars[:lcp])}"
    puts "scp (second_previous_cycle_profit):         #{vars[:scp].nil? ? '---' : format('%.5f', vars[:scp])}"
    puts "bpp (bot_profit):                           #{vars[:bpp].nil? ? '---' : format('%.5f', vars[:bpp])}"
    puts ""
    puts "vst (short_term_volatility):                #{vars[:vst].nan? ? '---' : format('%.5f', vars[:vst])}"
    puts "vlt (long_term_volatility):                 #{vars[:vlt].nan? ? '---' : format('%.5f', vars[:vlt])}"
    puts ""
    puts "cpr (current_price):                        #{vars[:cpr].nil? ? '---' : "#{vars[:cpr]} #{symbol_quote}"}"
    puts "ppr (previous_price):                       #{vars[:ppr].nil? ? '---' : "#{vars[:ppr]} #{symbol_quote}"}"
    puts "cma (current_moving_avg):                   #{vars[:cma].nan? ? '---' : format('%.18f %s', vars[:cma], symbol_quote)}"
    puts "lma (longterm_moving_avg):                  #{vars[:lma].nan? ? '---' : format('%.18f %s', vars[:lma], symbol_quote)}"
    puts "tma (triterm_moving_avg):                   #{vars[:tma].nan? ? '---' : format('%.18f %s', vars[:tma], symbol_quote)}"
    puts "rhi (rolling_high):                         #{vars[:rhi].nan? ? '---' : format('%.18f %s', vars[:rhi], symbol_quote)}"
    puts ""
    puts "ibp (initial_buy_price):                    #{vars[:ibp].nil? ? '---' : "#{vars[:ibp]} #{symbol_quote}"}"
    puts "cap (created_at_price):                     #{cycle.created_at_price.nil? ? '---' : "#{cycle.created_at_price} #{symbol_quote}"}"
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
    puts "crt (created_at):                           #{time_ago_in_words(vars[:crt])} ago"
    puts "lba (last_buy_at):                          #{vars[:lba].nil? ? '---' : "#{time_ago_in_words(vars[:lba])} ago"}"
    puts "lta (last_trade_at):                        #{vars[:lta].nil? ? '---' : "#{time_ago_in_words(vars[:lta])} ago"}"

    list_strategy(bot)
  end

  desc "Cycles"
  # Usage:
  #   rake bots:cycles[2]
  task :cycles, [:bot_id] => :environment do |_t, args|
    bot_id = args[:bot_id]
    raise ArgumentError, "Missing bot_id" unless bot_id

    bot = Bot.find_by(id: bot_id)
    raise ArgumentError, "Invalid bot_id: #{bot_id}" unless bot

    puts "\n== Cycles for Bot ##{bot.id} - Strategy: #{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes}) =="

    header = "%-6s %-20s %-20s %8s %12s %12s %10s" % [
      "#", "Started At", "Ended At", "Duration", "ETH In", "ETH Out", "Profit %"
    ]
    puts header
    puts "-" * header.length

    bot.bot_cycles.order(:started_at).each_with_index do |cycle, idx|
      cycle_num  = idx + 1
      started_at = cycle.started_at.strftime("%Y-%m-%d %H:%M:%S")
      ended_at   = cycle.ended_at ? cycle.ended_at.strftime("%Y-%m-%d %H:%M:%S") : "open"

      # duration: ended_at minus started_at, or now minus started_at if still open
      duration_minutes = (( (cycle.ended_at || Time.current) - cycle.started_at ) / 60).to_i

      eth_in   = cycle.initial_buy_amount.to_f
      eth_out  = (!cycle.open? && cycle.initial_buy_made?) ? cycle.quote_token_amount.to_f : 0.0
      profit   = cycle.profit_percentage.to_f

      puts "%-6d %-20s %-20s %8d %12.6f %12.6f %9.2f%%" % [
        cycle_num,
        started_at,
        ended_at,
        duration_minutes,
        eth_in,
        eth_out,
        profit
      ]
    end

    list_strategy(bot)
  end

  desc "List active bots; pass 'profit' to sort by profit percentage"
  task :list, [:sort_by] => :environment do |t, args|
    # default to last_action if no arg given
    args.with_defaults(sort_by: 'last_action')
    sort_key = args[:sort_by]

    bots = Bot.active
              .joins(:trades)
              .where(trades: { status: 'completed' })
              .distinct
              .to_a

    bots = case sort_key
           when 'profit'
             bots.sort_by(&:profit_percentage).reverse
           else
             bots.sort_by(&:last_action_at).reverse
           end

    header_label = sort_key == 'profit' ? 'profit %' : 'last action'
    puts "\n== Active Bots (#{bots.count}) — sorted by #{header_label} =="
    list_bots(bots)
  end

  desc "List all bots"
  task :list_all => :environment do
    bots = Bot.active.to_a.sort_by(&:last_action_at).reverse
    puts "\n== All Active Bots (#{bots.count}) =="
    list_bots(bots)
  end

  desc "List trades for a bot"
  # Usage:
  #   rake bots:trades[<bot_id>]
  task :trades, [:bot_id] => :environment do |_t, args|
    bot_id = args[:bot_id]
    raise ArgumentError, "Missing bot_id" unless bot_id

    bot = Bot.find_by(id: bot_id)
    raise ArgumentError, "Invalid bot_id: #{bot_id}" unless bot

    trades = bot.trades
                .where(status: %w[completed failed])
                .order(:executed_at)

    puts "\n== #{trades.count} Trades for Bot ##{bot.id} =="

    header = "%-6s %-6s %-10s %-6s %-20s %18s %18s %18s" % [
      "#", "Type", "Strategy", "Step", "Executed At",
      "Price", "Token In", "Token Out"
    ]
    puts header
    puts "-" * header.length

    trades.each do |trade|
      metrics      = trade.metrics || {}
      strategy     = metrics["strategy"].to_s
      mam          = metrics["mam"].to_i
      strategy_str = "#{strategy} (#{mam})"

      # only show step/in/out for completed trades
      #step_str = trade.status == "completed" ? metrics["step"].to_s : ""
      step_str = metrics["step"].to_s
      in_str   = trade.status == "completed" ? sprintf("%0.6f", trade.amount_in.to_f)  : ""
      out_str  = trade.status == "completed" ? sprintf("%0.6f", trade.amount_out.to_f) : ""

      executed_at = trade.executed_at.strftime("%Y-%m-%d %H:%M:%S")
      price       = trade.price.to_f

      puts "%-6d %-6s %-10s %-6s %-20s %18.12f %18s %18s" % [
        trade.id,
        trade.trade_type.upcase,
        strategy_str,
        step_str,
        executed_at,
        price,
        in_str,
        out_str
      ]
    end

    list_strategy(bot)
  end

  desc "Show strategy"
  # Usage:
  #   rake bots:trades[<bot_id>]
  task :strategy, [:bot_id] => :environment do |_t, args|
    bot_id = args[:bot_id]
    raise ArgumentError, "Missing bot_id" unless bot_id

    bot = Bot.find_by(id: bot_id)
    raise ArgumentError, "Invalid bot_id: #{bot_id}" unless bot

    list_strategy(bot)
  end

  private

  def list_bots(bots)
    #    ID     Token           Strat          Tokens            ETH       Init      Value   Profit%  Cycles Sells  Last Action At
    header_fmt = "%-6s %-14s %-8s %15s %10s %9s %10s %9s %7s %6s  %-20s"
    row_fmt    = "%-6s %-14s %-8s %15.5f %10.6f %9.4f %10.6f %+9.2f %7d %6d  %-20s"

    puts header_fmt % [
      "ID",
      "Token",
      "Strategy",
      "Tokens",
      "ETH",
      "Init",
      "Value",
      "Profit%",
      "Cycles",
      "Sells",
      "Last Action At"
    ]
    puts "-" * 114

    bots.each do |bot|
      token_symbol = bot.token_pair.base_token.symbol.delete("\r\n").strip  
      puts row_fmt % [
        bot.id,
        #bot.token_pair.base_token.symbol[0...12],
        token_symbol[0...12],
        "#{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes})",
        bot.current_cycle.base_token_amount.round(6),
        bot.current_cycle.quote_token_amount.round(6),
        bot.initial_buy_amount,
        bot.current_value,
        bot.profit_percentage,
        bot.bot_cycles.count,
        bot.sell_count,
        "#{time_ago_in_words(bot.last_action_at)} ago"
      ]
    end
  end

  def list_strategy(bot)
    strategy = JSON.parse(bot.strategy_json)

    puts "\n== Strategy #{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes}) for Bot ##{bot.id} =="
    puts "-" * 40
    strategy.each_with_index do |step,index|
      puts "#{index+1}: #{step}"
    end
  end 
end