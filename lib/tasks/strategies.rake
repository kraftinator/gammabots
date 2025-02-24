namespace :strategies do

  desc "Test strategy"
  # Usage:
  # rake strategies:test["1"]
  task :test, [:bot_id] => :environment do |t, args|
    if args[:bot_id].nil?
      raise ArgumentError, "Missing parameters!"
    end

    bot = Bot.find(args[:bot_id])
    unless bot
      raise ArgumentError, "Invalid bot!"
    end

    # The bot's strategy JSON would normally come from its associated strategy.
    # For testing purposes, we use a hardcoded strategy JSON:
    # Old version:
    # strategy_json = '[{"c":"cp<=ib*0.8","a":["sell all","deact"]},{"c":"cp>=ib*1.2&&st==0","a":["sell ba*0.25"]},{"c":"cp>=ib*1.5&&st==1","a":["sell ba*0.25"]},{"c":"cp<=hib*0.8&&st==2","a":["sell all","deact"]}]'
    #
    # New version with three-character variable names:
    strategy_json = '[{"c":"cpr<=ibp*0.95","a":["sell all","deact"]},' \
                    '{"c":"cpr>=ibp*1.2&&scn==0","a":["sell bta*0.25"]},' \
                    '{"c":"cpr>=ibp*1.5&&scn==1","a":["sell bta*0.25"]},' \
                    '{"c":"cpr<=hip*0.8&&scn==2","a":["sell all","deact"]}]'
    variables = bot.strategy_variables
    # The bot.strategy_variables method should now return keys using the new names:
    # {
    #   cpr: token_pair.latest_price,
    #   ibp: initial_buy_price,
    #   scn: trades.where(trade_type: "sell").count,
    #   bta: base_token_amount,
    #   hip: highest_price_since_initial_buy,
    #   hlt: highest_price_since_last_trade,
    #   ... (others, as needed)
    #   plus additional context (bot, provider_url) that is not exposed to the strategy evaluator.
    #
    TradingStrategyInterpreter.new(strategy_json, variables).execute
  end

  desc "Create strategy"
  # Usage:
  # rake strategies:create
  task :create => :environment do

    # Get Chain
    chain = Chain.find_by(name: "base_mainnet")
    unless chain
      raise ArgumentError, "Invalid chain"
    end

    # Old commented-out strategy:
    # strategy_json =
    #  '[{"c":"cp<=ib*0.95","a":["sell all","deact"]},' \
    #  '{"c":"sc==0&&hib>=ib*2.0&&cp<=hib*0.90","a":["sell bta*0.50"]},' \
    #  '{"c":"sc>0&&cp<=hlt*0.90","a":["sell bta*0.25"]}]'

    # New version with three-character variable names:
    strategy_json = '[{"c":"cpr<=ibp*0.95","a":["sell all","deact"]},' \
                    '{"c":"cpr>=ibp*1.05&&scn==0","a":["sell bta*0.25"]},' \
                    '{"c":"cpr>=ibp*1.1&&scn==1","a":["sell bta*0.25"]},' \
                    '{"c":"cpr<=hip*0.95&&scn==2","a":["sell all","deact"]}]'

    strategy = Strategy.create(
      chain: chain,
      contract_address: "abcdef123456",
      nft_token_id: "4",
      strategy_json: strategy_json
    )
    if strategy.valid?
      puts "Strategy created: #{strategy.id}"
    else
      puts "Creation failed: #{strategy.errors.messages}"
    end
  end
end
