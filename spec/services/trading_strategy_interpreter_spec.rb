# spec/services/trading_strategy_interpreter_spec.rb
require 'rails_helper'

RSpec.describe TradingStrategyInterpreter do
  # Our minimized JSON strategy:
  let(:strategy_json) do
    '[{"c":"cp<=ib*0.8","a":["sell all","deact"]},' \
    '{"c":"cp>=ib*1.2&&sc==0","a":["sell bta*0.25"]},' \
    '{"c":"cp>=ib*1.5&&sc==1","a":["sell bta*0.25"]},' \
    '{"c":"cp<=hib*0.8&&sc==2","a":["sell all","deact"]}]'
  end
  
  let(:strategy_json2) do
    '[{"c":"cp<=ib*0.8","a":["sell all","deact"]},' \
    '{"c":"sc==0&&hib>=ib*2.0&&cp<=hib*0.90","a":["sell bta*0.50"]},' \
    '{"c":"sc>0&&cp<=hlt*0.90","a":["sell bta*0.25"]}]'
  end
  

  let(:provider_url) { "http://fakeprovider.com" }

  # Create a fake bot that responds to base_token_amount and update! calls.
  let(:bot) do
    instance_double("Bot", base_token_amount: 100).tap do |b|
      allow(b).to receive(:update!)
    end
  end

    # A helper to build the variables mapping
    def strategy_variables(overrides = {})
    {
      cp: 100,    # current price (default, can be overridden)
      ib: 100,    # initial buy price
      sc: 0,      # sell trade count
      bta: 100,    # base token amount
      hib: 150,   # highest price since initial buy
      hlt: 140,   # highest price since last trade
      bot: bot,
      provider_url: provider_url
    }.merge(overrides)
  end

  # Each test will supply a variables hash mapping our abbreviated names to values.
  # For clarity:
  #   cp: current price
  #   ib: initial buy price
  #   sc: sell trade count
  #   bta: base token amount
  #   hib: highest price since initial buy

  context "with strategy 1" do
    subject { described_class.new(strategy_json, variables) }

    context "when rule 1 matches (cp<=ib*0.8)" do
      let(:variables) do
        {
          cp: 80,      # current price
          ib: 100,     # initial buy price
          sc: 0,       # sell trade count
          bta: 100,     # base token amount
          hib: 150,    # highest price since initial buy (not used here)
          bot: bot,
          provider_url: provider_url
        }
      end

      it "executes sell all and deact" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when rule 2 matches (cp>=ib*1.2 && st==0)" do
      let(:variables) do
        {
          cp: 130,     # current price
          ib: 100,
          sc: 0,
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        }
      end

      it "executes sell ba*0.25 (i.e., 25 tokens)" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 25, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end

    context "when rule 3 matches (cp>=ib*1.5 && st==1)" do
      let(:variables) do
        {
          cp: 160,     # current price
          ib: 100,
          sc: 1,
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        }
      end

      it "executes sell ba*0.25 (i.e., 25 tokens)" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 25, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end

    context "when rule 4 matches (cp<=hib*0.8 && st==2)" do
      let(:variables) do
        {
          cp: 110,     # current price such that 110<=150*0.8 (150*0.8 = 120)
          ib: 100,
          sc: 2,
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        }
      end

      it "executes sell all and deact" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when no rule matches" do
      let(:variables) do
        {
          cp: 105,    # current price that does not satisfy any condition
          ib: 100,
          sc: 3,      # sell trade count doesn't match any rule
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        }
      end

      it "executes no actions" do
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end
  end

  context "with strategy 2" do
    subject { described_class.new(strategy_json2, strategy_variables) }

    # Now you can write tests specific to strategy_json2.
    context "when stop-loss rule matches" do
      let(:vars) { strategy_variables(cp: 80) } # cp <= ib*0.8 (80<=100*0.8)
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell all and deact" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when profit capture on first sell matches" do
      let(:vars) { strategy_variables(cp: 130, sc: 0, hib: 220) } # cp<=hib*0.90: 130<=220*0.90 (198), hib>=ib*2.0: 220>=200
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell ba*0.50 (i.e., 50 tokens)" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 50, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end

    context "when trailing sell rule matches" do
      let(:vars) { strategy_variables(cp: 120, sc: 1, hlt: 140) } # cp<=hlt*0.90: 120<=140*0.90 (126)
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell ba*0.25 (i.e., 25 tokens)" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 25, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end
  end
end
