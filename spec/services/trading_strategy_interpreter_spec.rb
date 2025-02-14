# spec/services/trading_strategy_interpreter_spec.rb
require 'rails_helper'

RSpec.describe TradingStrategyInterpreter do
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

  # Create a fake bot. We assume bot.base_token_amount returns the base token amount.
  let(:bot) do
    instance_double("Bot", base_token_amount: 100).tap do |b|
      allow(b).to receive(:update!)
    end
  end

  # Helper to build the variables mapping. Our abbreviations:
  # cp: current price, ib: initial buy price, sc: sell count,
  # bta: base token amount, hib: highest price since initial buy, hlt: highest price since last trade.
  def strategy_variables(overrides = {})
    {
      cp: 100,    # current price
      ib: 100,    # initial buy price
      sc: 0,      # sell count
      bta: 100,   # base token amount
      hib: 150,   # highest price since initial buy
      hlt: 140,   # highest price since last trade
      bot: bot,
      provider_url: provider_url
    }.merge(overrides)
  end

  context "with strategy 1" do
    subject { described_class.new(strategy_json, variables) }

    context "when rule 1 matches (cp<=ib*0.8)" do
      let(:variables) do
        strategy_variables(
          cp: 80,    # satisfies cp<=100*0.8 (80<=80)
          ib: 100,
          sc: 0,
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        )
      end

      it "executes sell all and deact" do
        # For rule 1, condition: cp<=ib*0.8, multiplier = 0.8, target_price = 100*0.8 = 80,
        # sell all means sell 100, so min_amount_out = 100 * 80 = 8000.
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, 8000, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when rule 2 matches (cp>=ib*1.2 && sc==0)" do
      let(:variables) do
        strategy_variables(
          cp: 130,    # satisfies cp>=100*1.2 (130>=120)
          ib: 100,
          sc: 0,
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        )
      end

      it "executes sell bta*0.25 (i.e., 25 tokens) with min_amount_out = 25*120 = 3000" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 25, 3000, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end

    context "when rule 3 matches (cp>=ib*1.5 && sc==1)" do
      let(:variables) do
        strategy_variables(
          cp: 160,    # satisfies cp>=100*1.5 (160>=150)
          ib: 100,
          sc: 1,
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        )
      end

      it "executes sell bta*0.25 (i.e., 25 tokens) with min_amount_out = 25*150 = 3750" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 25, 3750, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end

    context "when rule 4 matches (cp<=hib*0.8 && sc==2)" do
      let(:variables) do
        strategy_variables(
          cp: 110,    # satisfies cp<=150*0.8 (110<=120)
          ib: 100,
          sc: 2,
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        )
      end

      it "executes sell all and deact with min_amount_out = 100 * (150*0.8) = 12000" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, 12000, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when no rule matches" do
      let(:variables) do
        strategy_variables(
          cp: 105,    # does not satisfy any condition
          ib: 100,
          sc: 3,      # no matching rule
          bta: 100,
          hib: 150,
          bot: bot,
          provider_url: provider_url
        )
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

    context "when stop-loss rule matches" do
      let(:vars) { strategy_variables(cp: 80) } # cp<=100*0.8 holds
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell all and deact with min_amount_out = 100 * (100*0.8) = 8000" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, 8000, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when profit capture on first sell matches" do
      let(:vars) { strategy_variables(cp: 130, sc: 0, hib: 220) }
      # For rule: "sc==0&&hib>=ib*2.0&&cp<=hib*0.90"
      # From the condition, extract multiplier from "ib*2.0" => 2.0.
      # Sell action: "sell bta*0.50" → sell_amount = 100*0.50 = 50.
      # target_price = ib * 2.0 = 100 * 2.0 = 200.
      # min_amount_out = 50 * 200 = 10000.
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell bta*0.50 (i.e., 50 tokens) with min_amount_out = 10000" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 50, 10000, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end

    context "when trailing sell rule matches" do
      let(:vars) { strategy_variables(cp: 120, sc: 1, hlt: 140) }
      # For rule: "sc>0&&cp<=hlt*0.90"
      # Since no explicit multiplier is found (because condition doesn't contain an "ib*<value>" part),
      # our extract_threshold_multiplier returns nil, so min_amount_out = 0.
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell bta*0.25 (i.e., 25 tokens) with min_amount_out = 0" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 25, 0, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end
  end
end