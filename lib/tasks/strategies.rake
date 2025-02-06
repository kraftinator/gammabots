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

end