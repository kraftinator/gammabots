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

  desc "Create bot via CreateBotService"
  # Usage (examples):
  #   rake bots:create_from_service["1","0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed","0.0005","4","6","base_mainnet"]
  #   rake bots:create_from_service["1","0x4ed4E...","0.0005","4","6","base_mainnet","0.40","0.08"]
  task :create_from_service,
       [:user_id,
        :token_contract_address,
        :initial_amount,
        :strategy_token_id,
        :moving_avg_minutes,
        :chain_name,
        :profit_share,
        :profit_threshold] => :environment do |_, args|

    mandatory = %i[
      user_id token_contract_address initial_amount
      strategy_token_id moving_avg_minutes chain_name
    ]
    missing = mandatory.select { |key| args[key].nil? }
    raise ArgumentError, "Missing parameters: #{missing.join(', ')}" unless missing.empty?

    service_args = {
      user_id:               args[:user_id],
      token_contract_address: args[:token_contract_address],
      initial_amount:         args[:initial_amount],
      strategy_token_id:      args[:strategy_token_id],
      moving_avg_minutes:     args[:moving_avg_minutes],
      chain_name:             args[:chain_name]
    }

    # Include optional params only if supplied
    service_args[:profit_share]     = args[:profit_share]     if args[:profit_share].present?
    service_args[:profit_threshold] = args[:profit_threshold] if args[:profit_threshold].present?

    bot = CreateBotService.call(**service_args)

    puts bot ? "Bot Created: #{bot.id}" : "Failed to create bot!"
  end

  desc "Create copy bot from service"
  # Usage:
  # rake bots:create_from_service["1","XXXXX","0.0005","4","6","base_mainnet"]
  task :create_copy_bot_from_service, [:user_id, :copy_wallet_address, :initial_amount, :strategy_token_id, :moving_avg_minutes, :chain_name] => :environment do |t, args|
    if args[:user_id].nil? || args[:copy_wallet_address].nil? || args[:initial_amount].nil? || args[:strategy_token_id].nil? || args[:moving_avg_minutes].nil? || args[:chain_name].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = CreateCopyBotService.call(
      user_id: args[:user_id],
      copy_wallet_address: args[:copy_wallet_address],
      initial_amount: args[:initial_amount],
      strategy_token_id: args[:strategy_token_id],
      moving_avg_minutes: args[:moving_avg_minutes],
      chain_name: args[:chain_name]
    )

    puts bot ? "Copy Bot Created: #{bot.id}" : "Failed to create copy bot!"
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
  task :list_retired, [:sort_by, :days] => :environment do |t, args|
    # default to sorting by last action and default days to 7
    args.with_defaults(sort_by: 'last_action', days: '7')
    days     = args[:days].to_i
    sort_key = args[:sort_by]

    bots = Bot.inactive
              .joins(:trades)
              .where(
                created_at: days.days.ago..Time.current,
                trades:      { status: 'completed' }
              )
              .distinct
              .to_a

    bots = case sort_key
          when 'profit'
            bots.sort_by { |bot| bot.profit_percentage(include_profit_withdrawals: true) }.reverse
          else
            bots.sort_by(&:last_action_at).reverse
          end

    label = sort_key == 'profit' ? 'profit %' : 'last action'
    puts "\n== Recently Retired Bots (#{bots.count}) — sorted by #{label} (last #{days} days) =="
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
             bots.sort_by { |bot| bot.profit_percentage(include_profit_withdrawals: true) }.reverse
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

  # Usage:
# rake bots:metrics["2"]
task :metrics, [:bot_id, :minutes] => :environment do |t, args|
  args.with_defaults(minutes: 1440)  # default to last 24h

  if args[:bot_id].nil?
    raise ArgumentError, "Missing parameters!"
  end

  bot = Bot.find(args[:bot_id])
  unless bot
    raise ArgumentError, "Invalid bot!"
  end

  since   = args[:minutes].to_i.minutes.ago
  metrics = bot.bot_price_metrics.where('created_at >= ?', since).order(:created_at)
  puts "\nMETRICS (#{bot.token_pair.name})"
  puts "---------"

  previous_price = nil
  metrics.each do |metric|
    
    price_diff_pct = if previous_price
                       ((metric.price - previous_price) / previous_price * 100).round(2)
                     else
                       0
                     end
    price_diff_sign = ' '
    if previous_price
      price_diff_sign = '-' if price_diff_pct < 0
      price_diff_sign = '+' if price_diff_pct > 0
    end
    vars = metric.metrics

    cma = vars[:cma] == 'NaN' ? nil : vars[:cma].to_d
    lma = vars[:lma] == 'NaN' ? nil : vars[:lma].to_d
    tma = vars[:tma] == 'NaN' ? nil : vars[:tma].to_d
    pcm = vars[:pcm] == 'NaN' ? nil : vars[:pcm].to_d
    plm = vars[:plm] == 'NaN' ? nil : vars[:plm].to_d
    rhi = vars[:rhi] == 'NaN' ? nil : vars[:rhi].to_d
    lps = vars[:lps] == 'NaN' ? nil : vars[:lps].to_d
    lmc = vars[:lmc] == 'NaN' ? nil : vars[:lmc].to_d
    ssd = vars[:ssd] == 'NaN' ? nil : vars[:ssd].to_d
    lsd = vars[:lsd] == 'NaN' ? nil : vars[:lsd].to_d
    vst = vars[:vst] == 'NaN' ? nil : vars[:vst].to_d
    vlt = vars[:vlt] == 'NaN' ? nil : vars[:vlt].to_d
    mom = vars[:mom] == 'NaN' ? nil : vars[:mom].to_d
    
    golden_crossover = false
    golden_crossover = (cma>lma && pcm<plm) if cma && lma && pcm && plm

    cpr_ppr_pct = if vars[:cpr] && vars[:ppr] && vars[:ppr] != 0
                ((vars[:cpr].to_f - vars[:ppr].to_f) / vars[:ppr].to_f * 100).round(2)
              else
                0.0
              end

    cma_lma_pct = if cma && lma && lma != 0
                    ((cma.to_f - lma.to_f) / lma.to_f * 100).round(2)
                  else
                    0.0
                  end

        pcm_plm_pct = if pcm && plm && plm != 0
                    ((pcm.to_f - plm.to_f) / plm.to_f * 100).round(2)
                  else
                    0.0
                  end

    lma_tma_pct = if lma && tma && tma != 0
                    ((lma.to_f - tma.to_f) / tma.to_f * 100).round(2)
                  else
                    0.0
                  end

    cpr_cma_pct = if vars[:cpr] && cma && cma != 0
                    ((vars[:cpr].to_f - cma.to_f) / cma.to_f * 100).round(2)
                  else
                    0.0
                  end

    cpr_rhi_pct = if vars[:cpr] && rhi && rhi != 0
                    ((vars[:cpr].to_f - rhi.to_f) / rhi.to_f * 100).round(2)
                  else
                    0.0
                  end

    ppr_rhi_pct = if vars[:ppr] && rhi && rhi != 0
                    ((vars[:ppr].to_f - rhi.to_f) / rhi.to_f * 100).round(2)
                  else
                    0.0
                  end

    cpr_lps_pct = if vars[:cpr] && lps && lps != 0
                    ((vars[:cpr].to_f - lps.to_f) / lps.to_f * 100).round(2)
                  else
                    0.0
                  end

    cma_lmc_pct = if cma && lmc && lmc != 0
                    ((cma.to_f - lmc.to_f) / lmc.to_f * 100).round(2)
                  else
                    0.0
                  end

    lsd_ssd_pct = if lsd && ssd && ssd != 0
                    ((lsd.to_f - ssd.to_f) / ssd.to_f * 100).round(2)
                  else
                    0.0
                  end

    vlt_vst_pct = if vlt && vst && vst != 0
                    ((vlt.to_f - vst.to_f) / vst.to_f * 100).round(2)
                  else
                    0.0
                  end

    cpr_tma_pct = if vars[:cpr] && tma && tma != 0
                    ((vars[:cpr].to_f - tma.to_f) / tma.to_f * 100).round(2)
                  else
                    0.0
                  end

    rhi_cma_pct = if rhi && cma && cma != 0
                    ((rhi.to_f - cma.to_f) / cma.to_f * 100).round(2)
                  else
                    0.0
                  end

    vst_mom_ratio = if vst && mom && mom != 0
                      (vst.to_f / mom.to_f).round(5)
                    else
                      0.0
                    end

    puts "#{metric.created_at} - #{metric.price.to_s}  #{price_diff_sign}#{price_diff_pct.abs}%"
    puts

    # Left column - existing metrics
    left_lines = [
      "golden crossover:             #{golden_crossover}",
      "mam (moving_avg_minutes):     #{vars[:mam]}",
      "cpr (current_price):          #{vars[:cpr]}",
      "ppr (previous_price):         #{vars[:ppr]}",
      "rhi (rolling_high):           #{vars[:rhi].nil? || vars[:rhi] == 'NaN' ? '' : format('%.18f %s', vars[:rhi], '')}",
      "cma (current_moving_avg):     #{vars[:cma] == 'NaN' ? '' : format('%.18f %s', vars[:cma], '')}",
      "lma (longterm_moving_avg):    #{vars[:lma] == 'NaN' ? '' : format('%.18f %s', vars[:lma], '')}",
      "tma (triterm_moving_avg):     #{vars[:tma] == 'NaN' ? '' : format('%.18f %s', vars[:tma], '')}",
      "pcm (previous_cma):           #{vars[:pcm].nil? || vars[:pcm] == 'NaN' ? '' : format('%.18f %s', vars[:pcm], '')}",
      "plm (previous_lma):           #{vars[:plm].nil? || vars[:plm] == 'NaN' ? '' : format('%.18f %s', vars[:plm], '')}",
      "ssd (short_stdev):            #{vars[:ssd].nil? || vars[:ssd] == 'NaN' ? '' : format('%.5f', vars[:ssd])}",
      "lsd (long_stdev):             #{vars[:lsd].nil? || vars[:lsd] == 'NaN' ? '' : format('%.5f', vars[:lsd])}",
      "vst (short_term_volatility):  #{vars[:vst].nil? || vars[:vst] == 'NaN' ? '' : format('%.5f', vars[:vst])}",
      "vlt (long_term_volatility):   #{vars[:vlt].nil? || vars[:vlt] == 'NaN' ? '' : format('%.5f', vars[:vlt])}",
      "ndp (price_non_decreasing):   #{vars[:ndp]}",
      "nd2 (price_non_decreasing_2): #{vars[:nd2]}",
      "pdi (price_diversity):        #{vars[:pdi].nil? || vars[:pdi] == 'NaN' ? '' : format('%.5f', vars[:pdi])}",
      "mom (momentum):               #{vars[:mom].nil? || vars[:mom] == 'NaN' ? '' : format('%.5f', vars[:mom])}"
    ]

    # Right column - additional metrics
    right_lines = [
      "cma > lma: #{format('%.2f', cma_lma_pct)}%",
      "pcm > plm: #{format('%.2f', pcm_plm_pct)}%",
      "lma > tma: #{format('%.2f', lma_tma_pct)}%",
      "cpr > ppr: #{format('%.2f', cpr_ppr_pct)}%",
      "cpr > cma: #{format('%.2f', cpr_cma_pct)}%",
      "cpr > rhi: #{format('%.2f', cpr_rhi_pct)}%",
      "cpr > tma: #{format('%.2f', cpr_tma_pct)}%",
      "rhi > cma: #{format('%.2f', rhi_cma_pct)}%",
      "ppr > rhi: #{format('%.2f', ppr_rhi_pct)}%",
      "cpr > lps: #{format('%.2f', cpr_lps_pct)}%",
      "cma > lmc: #{format('%.2f', cma_lmc_pct)}%",
      "lsd > ssd: #{format('%.2f', lsd_ssd_pct)}%",
      "vlt > vst: #{format('%.2f', vlt_vst_pct)}%",
      "vst / mom: #{format('%.5f', vst_mom_ratio)}",
    ]

    # Print both columns side by side
    max_lines = [left_lines.length, right_lines.length].max
    (0...max_lines).each do |i|
      left_text = left_lines[i] || ""
      right_text = right_lines[i] || ""
      
      # Pad left column to consistent width (adjust 70 as needed)
      left_padded = "#{' ' * 26}#{left_text}".ljust(80)
      puts "#{left_padded} | #{right_text}"
    end

    puts
    previous_price = metric.price
  end
end

  # Usage:
  # rake bots:metrics["2"]
  task :metrics2, [:bot_id, :minutes] => :environment do |t, args|
    args.with_defaults(minutes: 1440)  # default to last 24h

    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    since   = args[:minutes].to_i.minutes.ago
    metrics = bot.bot_price_metrics.where('created_at >= ?', since).order(:created_at)
    puts "\nMETRICS (#{bot.token_pair.name})"
    puts "---------"

    previous_price = nil
    metrics.each do |metric|
      
      price_diff_pct = if previous_price
                         ((metric.price - previous_price) / previous_price * 100).round(2)
                       else
                         0
                       end
      price_diff_sign = ' '
      if previous_price
        price_diff_sign = '-' if price_diff_pct < 0
        price_diff_sign = '+' if price_diff_pct > 0
      end
      vars = metric.metrics

      cma = vars[:cma] == 'NaN' ? nil : vars[:cma].to_d
      lma = vars[:lma] == 'NaN' ? nil : vars[:lma].to_d
      pcm = vars[:pcm] == 'NaN' ? nil : vars[:pcm].to_d
      plm = vars[:plm] == 'NaN' ? nil : vars[:plm].to_d 

      golden_crossover = false
      golden_crossover = (cma>lma && pcm<plm) if cma && lma && pcm && plm

      puts "#{metric.created_at} - #{metric.price.to_s}  #{price_diff_sign}#{price_diff_pct.abs}%"
      puts
      puts "                          mam (moving_avg_minutes):     #{vars[:mam]}"

      puts "                          cpr (current_price):          #{vars[:cpr]}"
      puts "                          ppr (previous_price):         #{vars[:ppr]}"
      puts "                          rhi (rolling_high):           #{vars[:rhi].nil? || vars[:rhi] == 'NaN' ? '' : format('%.18f %s', vars[:rhi], '')}"
      puts "                          cma (current_moving_avg):     #{vars[:cma] == 'NaN' ? '' : format('%.18f %s', vars[:cma], '')}"
      puts "                          lma (longterm_moving_avg):    #{vars[:lma] == 'NaN' ? '' : format('%.18f %s', vars[:lma], '')}"
      puts "                          tma (triterm_moving_avg):     #{vars[:tma] == 'NaN' ? '' : format('%.18f %s', vars[:tma], '')}"
      puts "                          pcm (previous_cma):           #{vars[:pcm].nil? || vars[:pcm] == 'NaN' ? '' : format('%.18f %s', vars[:pcm], '')}"
      puts "                          plm (previous_lma):           #{vars[:plm].nil? || vars[:plm] == 'NaN' ? '' : format('%.18f %s', vars[:plm], '')}"

      puts "                          ssd (short_stdev):            #{vars[:ssd].nil? || vars[:ssd] == 'NaN' ? '' : format('%.5f', vars[:ssd])}"
      puts "                          lsd (long_stdev):             #{vars[:lsd].nil? || vars[:lsd] == 'NaN' ? '' : format('%.5f', vars[:lsd])}"
      puts "                          vst (short_term_volatility):  #{vars[:vst].nil? || vars[:vst] == 'NaN' ? '' : format('%.5f', vars[:vst])}"
      puts "                          vlt (long_term_volatility):   #{vars[:vlt].nil? || vars[:vlt] == 'NaN' ? '' : format('%.5f', vars[:vlt])}"

      puts "                          ndp (price_non_decreasing):   #{vars[:ndp]}"
      puts "                          nd2 (price_non_decreasing_2): #{vars[:nd2]}"
      puts "                          pdi (price_diversity):        #{vars[:pdi].nil? || vars[:pdi] == 'NaN' ? '' : format('%.5f', vars[:pdi])}"
      puts "                          mom (momentum):               #{vars[:mom].nil? || vars[:mom] == 'NaN' ? '' : format('%.5f', vars[:mom])}"
      puts "                          golden crossover:             #{golden_crossover}"

      puts
      previous_price = metric.price
    end
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

    unless bot.token_pair
      puts "Bot ##{bot.id} has no token pair assigned yet!"
      exit
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
    puts "ndp (price_non_decreasing):                 #{vars[:ndp]}"
    puts "nd2 (price_non_decreasing_2):               #{vars[:nd2]}"
    puts "pdi (price_diversity_indicator):            #{vars[:pdi].nan? ? '---' : format('%.5f', vars[:pdi])}"
    puts "mom (momentum_indicator):                   #{vars[:mom].nan? ? '---' : format('%.5f', vars[:mom])}"
    puts ""
    puts "ssd (short_standard_dev_volatility):        #{vars[:ssd].nan? ? '---' : format('%.5f', vars[:ssd])}"
    puts "lsd (long_standard_dev_volatility):         #{vars[:lsd].nan? ? '---' : format('%.5f', vars[:lsd])}"
    puts "vst (short_term_volatility):                #{vars[:vst].nan? ? '---' : format('%.5f', vars[:vst])}"
    puts "vlt (long_term_volatility):                 #{vars[:vlt].nan? ? '---' : format('%.5f', vars[:vlt])}"
    puts ""
    puts "cpr (current_price):                        #{vars[:cpr].nil? ? '---' : "#{vars[:cpr]} #{symbol_quote}"}"
    puts "ppr (previous_price):                       #{vars[:ppr].nil? ? '---' : "#{vars[:ppr]} #{symbol_quote}"}"
    puts "cma (current_moving_avg):                   #{vars[:cma].nan? ? '---' : format('%.18f %s', vars[:cma], symbol_quote)}"
    puts "pcm (prev_current_moving_avg):              #{vars[:pcm].nan? ? '---' : format('%.18f %s', vars[:pcm], symbol_quote)}"
    puts "lma (longterm_moving_avg):                  #{vars[:lma].nan? ? '---' : format('%.18f %s', vars[:lma], symbol_quote)}"
    puts "plm (prev_longterm_moving_avg):             #{vars[:plm].nan? ? '---' : format('%.18f %s', vars[:plm], symbol_quote)}"
    puts "tma (triterm_moving_avg):                   #{vars[:tma].nan? ? '---' : format('%.18f %s', vars[:tma], symbol_quote)}"
    puts "rhi (rolling_high):                         #{vars[:rhi].nan? ? '---' : format('%.18f %s', vars[:rhi], symbol_quote)}"
    puts ""
    puts "ibp (initial_buy_price):                    #{vars[:ibp].nil? ? '---' : "#{vars[:ibp]} #{symbol_quote}"}"
    puts "lbp (listed_buy_price):                     #{vars[:lbp].nil? ? '---' : "#{vars[:lbp]} #{symbol_quote}"}"
    puts "bep (break_even_price):                     #{vars[:bep].nil? ? '---' : "#{vars[:bep]} #{symbol_quote}"}"
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
    puts "ndp (price_non_decreasing):                 #{vars[:ndp]}"
    puts "nd2 (price_non_decreasing):                 #{vars[:nd2]}"
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
    puts "pcm (prev_current_moving_avg):              #{vars[:pcm].nan? ? '---' : format('%.18f %s', vars[:pcm], symbol_quote)}"
    puts "plm (prev_longterm_moving_avg):             #{vars[:plm].nan? ? '---' : format('%.18f %s', vars[:plm], symbol_quote)}"

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
  task :cycles, [:bot_id, :analyze] => :environment do |_t, args|
    bot_id = args[:bot_id]
    raise ArgumentError, "Missing bot_id" unless bot_id

    bot = Bot.find_by(id: bot_id)
    raise ArgumentError, "Invalid bot_id: #{bot_id}" unless bot

    show_analysis = args[:analyze] == 'true' || args[:analyze] == '1'

    puts "\n== Cycles for Bot ##{bot.id} - Strategy: #{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes}) =="

    header = "%-6s %-20s %-20s %8s %12s %12s %10s %12s %12s" % [
      "#", "Started At", "Ended At", "Duration", "ETH In", "ETH Out", "Profit %", "Profit Out", "Adj ETH"
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
      #eth_out  = (!cycle.open? && cycle.initial_buy_made?) ? cycle.quote_token_amount.to_f : 0.0
      adj_eth_out  = (!cycle.open? && cycle.initial_buy_made?) ? cycle.quote_token_amount.to_f : 0.0
      eth_out = adj_eth_out + cycle.profit_taken
      profit   = cycle.profit_percentage(include_profit_withdrawals: true).to_f

      puts "%-6d %-20s %-20s %8d %12.6f %12.6f %9.2f%% %12.6f %12.6f" % [
        cycle_num,
        started_at,
        ended_at,
        duration_minutes,
        eth_in,
        eth_out,
        profit,
        cycle.profit_taken,
        adj_eth_out
      ]

      if show_analysis
        trade = cycle.initial_buy_trade
        if trade
          puts ""
          puts "#{trade.analyze_metrics}"
        end
      end
    end

    list_strategy(bot)
  end

  desc "List active bots; pass 'profit' to sort by profit percentage"
  # Usage
  #   rake bots:list
  #   rake bots:list[profit]
  #   rake bots:list[profit,nft_token_id]
  task :list, [:sort_by, :strategy_key] => :environment do |t, args|
    # default to last_action if no arg given
    args.with_defaults(sort_by: 'last_action')
    sort_key = args[:sort_by]
    strategy_key  = args[:strategy_key]

    bots = Bot.active
              .joins(:trades)
              .where(trades: { status: 'completed' })
              .distinct
              .to_a

    bots = case sort_key
           when 'profit'
             bots.sort_by { |bot| bot.profit_percentage(include_profit_withdrawals: true) }.reverse
           else
             bots.sort_by(&:last_action_at).reverse
           end

    # Apply strategy_key filter if provided
    if strategy_key
      bots.select! { |bot| bot.strategy.nft_token_id.to_s == strategy_key }
    end
    
    header_label = sort_key == 'profit' ? 'profit %' : 'last action'
    header_label += strategy_key ? " — strategy #{strategy_key}" : ''

    puts "\n== Active Bots (#{bots.count}) — sorted by #{header_label} =="
    list_bots(bots)
  end

  desc "List active bots that haven't made any trades yet"
  task :list_untraded => :environment do
    bots = Bot.active
              .left_outer_joins(:trades)
              .where(trades: { id: nil })
              .order(created_at: :desc)
              .distinct
              .to_a

    bots.sort_by(&:last_action_at).reverse
    puts "\n== Active Bots with No Trades Yet (#{bots.count}) =="
    list_bots(bots)
  end

  desc "List metrics catchers"
  task :list_metrics_catchers => :environment do
    bots = Bot.active
              .where(catch_metrics: true)
              .order(created_at: :desc)
              .distinct
              .to_a

    bots.sort_by(&:last_action_at).reverse
    puts "\n== Active Bots Catching Metrics (#{bots.count}) =="
    list_bots(bots)
  end

  desc "List all bots"
  task :list_all => :environment do
    #bots = Bot.active.to_a.sort_by(&:last_action_at).reverse
    #bots = Bot.active.where.not(token_pair_id: nil).to_a.sort_by(&:last_action_at).reverse
    bots = Bot.active.to_a.sort_by(&:last_action_at).reverse
    puts "\n== All Active Bots (#{bots.count}) =="
    list_bots(bots)
  end

  desc "List copy bots"
  task :list_copy_bots => :environment do
    bots = Bot.copy_bots.active.to_a.sort_by(&:last_action_at).reverse
    
    header_fmt = "%-6s %-44s %-12s %-10s %-14s  %-20s"
    row_fmt    = "%-6s %-44s %-12s %-10.6f %-14s  %-20s"

    puts header_fmt % [
      "ID",
      "Copy Address",
      "Strategy",
      "ETH",
      "Token",
      "Last Action At"
    ]
    puts "-" * 105

    bots.each do |bot|
      token_symbol = bot.token_pair.base_token.symbol.delete("\r\n").strip if bot.token_pair
      puts row_fmt % [
        bot.id,
        bot.copy_wallet_address,
        "#{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes})",
        bot.initial_buy_amount,
        token_symbol || '---',
        "#{time_ago_in_words(bot.last_action_at)} ago"
      ]
    end
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

    header = "%-6s %-6s %-6s %-10s %-6s %-20s %18s %18s %18s" % [
      "#", "Cycle", "Type", "Strategy", "Step", "Executed At",
      "Price", "Token In", "Token Out"
    ]
    puts header
    puts "-" * header.length

    trades.each do |trade|
      metrics      = trade.metrics || {}
      strategy     = metrics["strategy"].to_s
      mam          = metrics["mam"].to_i
      strategy_str = "#{strategy} (#{mam})"

      step_str = metrics["step"].to_s
      in_str   = trade.status == "completed" ? sprintf("%0.6f", trade.amount_in.to_f)  : ""
      out_str  = trade.status == "completed" ? sprintf("%0.6f", trade.amount_out.to_f) : ""

      executed_at = trade.executed_at.strftime("%Y-%m-%d %H:%M:%S")
      price       = trade.price.to_f

      puts "%-6d %-6d %-6s %-10s %-6s %-20s %18.12f %18s %18s" % [
        trade.id,
        trade.bot_cycle.ordinal,
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
    header_fmt = "%-6s %-14s %-8s %15s %10s %10s %10s %9s %10s %7s %6s %7s   %-8s  %-20s"
    row_fmt    = "%-6s %-14s %-8s %15.5f %10.6f %10.6f %10.6f %+9.2f %10.6f %7d %6d %7d   %-8s  %-20s"

    puts header_fmt % [
      "ID",
      "Token",
      "Strategy",
      "Tokens",
      "ETH",
      "Init",
      "Value",
      "Profit%",
      "Profit+",
      "Cycles",
      "Sells",
      "Errors",
      "Type",
      "Last Action At"
    ]
    puts "-" * 150

    bots.each do |bot|
      if bot.current_cycle
        token_symbol = bot.token_pair.base_token.symbol.delete("\r\n").strip
        puts row_fmt % [
          bot.id,
          token_symbol[0...12],
          "#{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes})",
          bot.current_cycle.base_token_amount.round(6),
          bot.current_cycle.quote_token_amount.round(6),
          bot.initial_buy_amount,
          bot.current_value,
          bot.profit_percentage(include_profit_withdrawals: true),
          bot.profit_taken,
          bot.bot_cycles.count,
          bot.sell_count,
          bot.bot_events.count,
          bot.bot_type,
          "#{time_ago_in_words(bot.last_action_at)} ago"
        ]
      else
        puts row_fmt % [
          bot.id,
          '---',
          "#{bot.strategy.nft_token_id} (#{bot.moving_avg_minutes})",
          0.0,
          0.0,
          bot.initial_buy_amount,
          bot.initial_buy_amount,
          0.0,
          0.0,
          bot.bot_cycles.count,
          bot.sell_count,
          bot.bot_events.count,
          bot.bot_type,
          "#{time_ago_in_words(bot.last_action_at)} ago"
        ]
      end
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