require 'rails_helper'

RSpec.describe TradingStrategy, type: :service do
  let(:chain) { create(:chain) }
  let(:base_token) { create(:token, chain: chain) }
  let(:quote_token) { create(:token, chain: chain) }
  let(:token_pair) { create(:token_pair, chain: chain, base_token: base_token, quote_token: quote_token) }
  let(:user) { create(:user) }
  let!(:wallet) { create(:wallet, user: user, chain: chain) }
  let(:bot) { create(:bot, user: user, chain: chain, token_pair: token_pair, initial_buy_price: 1.0, base_token_amount: 100) }
  let(:provider_url) { "http://mock.provider" }
  let(:strategy) { described_class.new(bot, provider_url: provider_url) }
  
  describe "#default_strategy" do
    context "when price drops 20% from initial buy" do
      it "sells all holdings and deactivates the bot" do
        puts "Wallet for chain: #{bot.user.wallet_for_chain(bot.chain).inspect}"
        puts "TokenPair: #{bot.token_pair.attributes.inspect}"
        puts "Base Token: #{bot.token_pair&.base_token.inspect}"

        puts "bot.token_pair.class = #{bot.token_pair.class}"
        #allow(bot).to receive(:token_pair).and_return(double(latest_price: 0.8)) # Simulate 20% drop
        allow(bot.token_pair).to receive(:latest_price).and_return(0.8)

        puts "bot.token_pair.class = #{bot.token_pair.class}"
        

        puts "***** FLAG 9 *****"
        expect(TradeExecutionService).to receive(:sell).with(bot, bot.base_token_amount, anything)
        puts "***** FLAG 10 *****"

        strategy.process
        expect(bot.active).to be_falsey
      end
    end

    context "when price increases 20% and no sells were made" do
      it "sells 25% of holdings" do
        allow(bot).to receive(:token_pair).and_return(double(latest_price: 1.2)) # Simulate 20% gain
        allow(bot.trades).to receive(:where).and_return([]) # No previous sells

        expect(TradeExecutionService).to receive(:sell).with(bot, 25, anything)
        
        strategy.process
      end
    end

    context "when price increases 50% and one sell was made" do
      it "sells another 25%" do
        allow(bot).to receive(:token_pair).and_return(double(latest_price: 1.5)) # Simulate 50% gain
        allow(bot.trades).to receive(:where).and_return([double]) # 1 sell trade exists

        expect(TradeExecutionService).to receive(:sell).with(bot, 25, anything)
        
        strategy.process
      end
    end

    context "when price drops 20% from highest_price_since_initial_buy and 2 sells were made" do
      it "sells everything and deactivates bot" do
        allow(bot).to receive(:token_pair).and_return(double(latest_price: 1.2)) # Price initially high
        allow(bot).to receive(:highest_price_since_initial_buy).and_return(1.5)
        allow(bot.trades).to receive(:where).and_return([double, double]) # 2 sells made

        expect(TradeExecutionService).to receive(:sell).with(bot, bot.base_token_amount, anything)
        
        strategy.process
        expect(bot.active).to be_falsey
      end
    end
  end
end
