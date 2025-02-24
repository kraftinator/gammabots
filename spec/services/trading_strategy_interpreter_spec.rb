# spec/services/trading_strategy_interpreter_spec.rb
require 'rails_helper'

RSpec.describe TradingStrategyInterpreter do
  let(:strategy_json) do
    '[{"c":"cpr<=ibp*0.8","a":["sell all","deact"]},' \
    '{"c":"cpr>=ibp*1.2&&scn==0","a":["sell bta*0.25"]},' \
    '{"c":"cpr>=ibp*1.5&&scn==1","a":["sell bta*0.25"]},' \
    '{"c":"cpr<=hip*0.8&&scn==2","a":["sell all","deact"]}]'
  end

  let(:strategy_json2) do
    '[{"c":"cpr<=ibp*0.8","a":["sell all","deact"]},' \
    '{"c":"scn==0&&hip>=ibp*2.0&&cpr<=hip*0.90","a":["sell bta*0.50"]},' \
    '{"c":"scn>0&&cpr<=hlt*0.90","a":["sell bta*0.25"]}]'
  end

  let(:provider_url) { "http://fakeprovider.com" }

  # Create a fake bot. We assume bot.base_token_amount returns the base token amount.
  let(:bot) do
    instance_double("Bot", base_token_amount: 100).tap do |b|
      allow(b).to receive(:update!)
    end
  end

  # Helper to build the variables mapping. Our abbreviations:
  # cpr: current price, ibp: initial buy price, scn: sell count,
  # bta: base token amount, hip: highest price since initial buy, hlt: highest price since last trade.
  # Note: provider_url and bot are not exposed as strategy variables.
  def strategy_variables(overrides = {})
    {
      cpr: 100,    # current price
      ibp: 100,    # initial buy price
      scn: 0,      # sell count
      bta: 100,    # base token amount
      hip: 150,    # highest price since initial buy
      hlt: 140,    # highest price since last trade
      bot: bot,                # not exposed in binding_from_variables
      provider_url: provider_url # not exposed in binding_from_variables
    }.merge(overrides)
  end

  context "with strategy 1" do
    subject { described_class.new(strategy_json, variables) }

    context "when rule 1 matches (cpr<=ibp*0.8)" do
      let(:variables) do
        strategy_variables(
          cpr: 80,    # satisfies 80<=100*0.8 (80<=80)
          ibp: 100,
          scn: 0,
          bta: 100,
          hip: 150,
          bot: bot,
          provider_url: provider_url
        )
      end

      it "executes sell all and deact" do
        # For rule 1, condition: cpr<=ibp*0.8, multiplier = 0.8, target_price = 100*0.8 = 80,
        # sell all means sell 100, so min_amount_out = 100 * 80 = 8000.
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, 8000, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when rule 2 matches (cpr>=ibp*1.2 && scn==0)" do
      let(:variables) do
        strategy_variables(
          cpr: 130,    # satisfies 130>=100*1.2 (130>=120)
          ibp: 100,
          scn: 0,
          bta: 100,
          hip: 150,
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

    context "when rule 3 matches (cpr>=ibp*1.5 && scn==1)" do
      let(:variables) do
        strategy_variables(
          cpr: 160,    # satisfies 160>=100*1.5 (160>=150)
          ibp: 100,
          scn: 1,
          bta: 100,
          hip: 150,
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

    context "when rule 4 matches (cpr<=hip*0.8 && scn==2)" do
      let(:variables) do
        strategy_variables(
          cpr: 110,    # satisfies 110<=150*0.8 (110<=120)
          ibp: 100,
          scn: 2,
          bta: 100,
          hip: 150,
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
          cpr: 105,    # does not satisfy any condition
          ibp: 100,
          scn: 3,      # no matching rule
          bta: 100,
          hip: 150,
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
      let(:vars) { strategy_variables(cpr: 80) } # satisfies cpr<=ibp*0.8 with ibp=100 (80<=80)
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell all and deact with min_amount_out = 100 * (100*0.8) = 8000" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 100, 8000, provider_url)
        expect(bot).to receive(:update!).with(active: false)
        subject.execute
      end
    end

    context "when profit capture on first sell matches" do
      let(:vars) { strategy_variables(cpr: 130, scn: 0, hip: 220, ibp: 100) }
      # For rule: "scn==0&&hip>=ibp*2.0&&cpr<=hip*0.90"
      # Extract from condition: use ibp*2.0 -> multiplier = 2.0, base = ibp.
      # Sell action: "sell bta*0.50" → sell_amount = 100*0.50 = 50.
      # target_price = ibp * 2.0 = 100*2.0 = 200.
      # min_amount_out = 50 * 200 = 10000.
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell bta*0.50 (i.e., 50 tokens) with min_amount_out = 10000" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 50, 10000, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end

    context "when trailing sell rule matches" do
      let(:vars) { strategy_variables(cpr: 120, scn: 1, hlt: 140) }
      # For rule: "scn>0&&cpr<=hlt*0.90"
      # No explicit multiplier is found, so min_amount_out = 0.
      subject { described_class.new(strategy_json2, vars) }

      it "executes sell bta*0.25 (i.e., 25 tokens) with min_amount_out = 0" do
        expect(TradeExecutionService).to receive(:sell).with(bot, 25, 0, provider_url)
        expect(bot).not_to receive(:update!)
        subject.execute
      end
    end
  end
end
