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

    #strategy_json = @bot.strategy.json
    #strategy_json = '[{"c":"cp<=ib*0.8","a":["sell all","deact"]},{"c":"cp>=ib*1.2&&st==0","a":["sell ba*0.25"]},{"c":"cp>=ib*1.5&&st==1","a":["sell ba*0.25"]},{"c":"cp<=hib*0.8&&st==2","a":["sell all","deact"]}]'
    strategy_json = '[{"c":"cp<=ib*0.95","a":["sell all","deact"]},{"c":"cp>=ib*1.2&&st==0","a":["sell ba*0.25"]},{"c":"cp>=ib*1.5&&st==1","a":["sell ba*0.25"]},{"c":"cp<=hib*0.8&&st==2","a":["sell all","deact"]}]'
    variables = bot.strategy_variables

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

    #strategy_json =     
    #  '[{"c":"cp<=ib*0.95","a":["sell all","deact"]},' \
    #  '{"c":"sc==0&&hib>=ib*2.0&&cp<=hib*0.90","a":["sell bta*0.50"]},' \
    #  '{"c":"sc>0&&cp<=hlt*0.90","a":["sell bta*0.25"]}]'

    strategy_json = 
      '[{"c":"cp<=ib*0.95","a":["sell all","deact"]},' \
      '{"c":"cp>=ib*1.05&&sc==0","a":["sell bta*0.25"]},' \
      '{"c":"cp>=ib*1.1&&sc==1","a":["sell bta*0.25"]},' \
      '{"c":"cp<=hib*0.95&&sc==2","a":["sell all","deact"]}]'

    strategy = Strategy.create(
      chain: chain,
      contract_address: "abcdef123456",
      nft_token_id: "4",
      strategy_json: strategy_json
    )
    if strategy.valid?
      puts "Strategy created: #{strategy.id.to_s}"
    else
      puts "Creation failed: #{strategy.errors.messages}"
    end
  end
end