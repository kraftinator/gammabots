class BotRunner
  def self.run(bot)
    return unless bot.active?
    #current_price = bot.token_pair.latest_price
    #provider_url = ProviderUrlService.get_provider_url(bot.chain.name)
    #TradingStrategy.process(bot, current_price, provider_url)
    strategy = TradingStrategy.new(bot)
    strategy.process
  end
end
