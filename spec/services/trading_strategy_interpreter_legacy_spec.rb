# frozen_string_literal: true

require "rails_helper"

RSpec.describe TradingStrategyInterpreter, type: :service do
  # --- Mock setup ------------------------------------------------------------
  let(:cycle) { instance_double(BotCycle, base_token_amount: 100.0) }

  let(:base_token) { instance_double("Token", symbol: "ETH") }
  let(:token_pair) { instance_double("TokenPair", base_token: base_token) }

  let(:bot) do
    instance_double(
      Bot,
      id: 1,
      deactivate: true,
      forced_deactivate: true,
      initial_buy_made?: true,
      current_cycle: cycle,
      provider_url: "https://example.com",
      token_pair: token_pair
    )
  end

  # Make condition “bcn==0” true so buy rules trigger
  let(:base_variables) do
    {
      bot: bot,
      cpr: 1.0,
      ibp: 1.0,
      bcn: 0,  # changed from 1
      scn: 0,
      bta: 100.0,
      lta: 10,
      lba: 10,
      crt: 10
    }
  end

  before do
    allow(TradeExecutionService).to receive(:buy).and_return(true)
    allow(TradeExecutionService).to receive(:sell).and_return(true)
  end

  # --- Tests ----------------------------------------------------------------
  describe "legacy vs new syntax" do
    context "for buy action" do
      let(:legacy_strategy) { [{ "c" => "bcn==0", "a" => ["buy init"] }].to_json }
      let(:new_strategy)    { [{ "c" => "bcn==0", "a" => ["buy"] }].to_json }

      it "interprets legacy 'buy init' identically to new 'buy'" do
        legacy = described_class.new(legacy_strategy, base_variables)
        newver = described_class.new(new_strategy, base_variables)

        legacy.execute
        newver.execute

        expect(TradeExecutionService).to have_received(:buy).twice
      end
    end

    context "for sell action" do
      let(:legacy_strategy) do
        [{ "c" => "bcn>0", "a" => ["sell bta*0.25"] }].to_json
      end
      let(:new_strategy) do
        [{ "c" => "bcn>0", "a" => ["sell 0.25"] }].to_json
      end

      it "interprets 'sell bta*0.25' identically to 'sell 0.25'" do
        # Make condition true for this one
        vars = base_variables.merge(bcn: 1)

        legacy = described_class.new(legacy_strategy, vars)
        newver = described_class.new(new_strategy, vars)

        legacy.execute
        newver.execute

        expect(TradeExecutionService).to have_received(:sell).twice
      end
    end

    context "for sell all" do
      let(:strategy) do
        [{ "c" => "bcn>0", "a" => ["sell all", "deact"] }].to_json
      end

      it "handles 'sell all' consistently" do
        allow(bot).to receive(:initial_buy_made?).and_return(true)
        vars = base_variables.merge(bcn: 1)

        interpreter = described_class.new(strategy, vars)
        interpreter.execute

        expect(TradeExecutionService).to have_received(:sell).once
        expect(bot).to have_received(:deactivate)
      end
    end

    context "for deact vs deact force" do
      let(:legacy_strategy) { [{ "c" => "bcn>0", "a" => ["deact force"] }].to_json }
      let(:new_strategy)    { [{ "c" => "bcn>0", "a" => ["deact"] }].to_json }

      it "still accepts 'deact force' and behaves equivalently when no initial buy" do
        allow(bot).to receive(:initial_buy_made?).and_return(false)
        vars = base_variables.merge(bcn: 1)

        legacy = described_class.new(legacy_strategy, vars)
        newver = described_class.new(new_strategy, vars)

        legacy.execute
        newver.execute

        expect(bot).to have_received(:forced_deactivate).at_least(:once)
      end
    end
  end

  describe "robustness" do
    it "ignores unknown actions gracefully (does not raise)" do
      strategy = [{ "c" => "bcn>0", "a" => ["dance"] }].to_json
      interpreter = described_class.new(strategy, base_variables.merge(bcn: 1))
      expect { interpreter.execute }.not_to raise_error
    end
  end
end