# frozen_string_literal: true

require "rails_helper"

RSpec.describe StrategiesValidate, type: :service do
  let(:valid_strategy_json) do
    [
      { "c" => "buyCount==0", "a" => ["buy"] },
      { "c" => "buyCount>0&&minSinceTrade>=1", "a" => ["sell all", "reset"] },
      { "c" => "buyCount>0&&currentPrice<=initBuyPrice*0.75", "a" => ["sell 0.5", "deact"] },
      {
        "c" => "buyCount>0&&sellCount==0&&highInitBuy>=initBuyPrice*2.0&&currentPrice<=highInitBuy*0.90",
        "a" => ["sell 0.25"]
      }
    ].to_json
  end

  let(:invalid_json) { "not a json" }

  describe ".call" do
    context "with valid strategy" do
      it "returns valid: true" do
        result = described_class.call(valid_strategy_json)
        expect(result[:valid]).to be(true)
      end

      it "returns compressed JSON with expected keys" do
        result = described_class.call(valid_strategy_json)
        parsed = JSON.parse(result[:compressed])
        expect(parsed).to all(include("c", "a"))
      end

      it "converts human-readable fields to compressed short codes" do
        result = described_class.call(valid_strategy_json)
        compressed = result[:compressed]
        %w[bcn lta cpr ibp scn].each do |short_code|
          expect(compressed).to include(short_code)
        end
      end
    end

    context "with malformed JSON" do
      it "returns invalid with JSON error" do
        result = described_class.call(invalid_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors]).to include("Invalid JSON")
      end
    end

    context "with missing keys" do
      let(:missing_conditions_json) { [{ "a" => ["buy"] }].to_json }

      it "returns error for missing 'c'" do
        result = described_class.call(missing_conditions_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors].first).to match(/missing 'c'/i)
      end
    end

    context "with unknown variables" do
      let(:unknown_var_json) { [{ "c" => "unknownField>0", "a" => ["buy"] }].to_json }

      it "returns invalid and lists the unknown variable" do
        result = described_class.call(unknown_var_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors].first).to include("Unknown variable 'unknownField'")
      end
    end

    context "with invalid action" do
      let(:invalid_action_json) { [{ "c" => "bcn==0", "a" => ["jump rope"] }].to_json }

      it "returns invalid and lists the unknown action" do
        result = described_class.call(invalid_action_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors].first).to include("Unknown action 'jump rope'")
      end
    end

    context "with invalid Dentaku expression" do
      let(:bad_operator_json) { [{ "c" => "bcn>==0", "a" => ["buy"] }].to_json }

      it "returns invalid and includes a Dentaku parse error" do
        result = described_class.call(bad_operator_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors].first).to match(/invalid expression/i)
      end
    end

    context "when conditions contain extra whitespace" do
      let(:whitespace_json) { [{ "c" => " bcn  ==  0  &&  lta  >=  1 ", "a" => ["buy"] }].to_json }

      it "removes unnecessary spaces in compressed JSON" do
        result = described_class.call(whitespace_json)
        expect(result[:valid]).to be(true)
        compressed = JSON.parse(result[:compressed]).first["c"]
        expect(compressed).to eq("bcn==0&&lta>=1")
      end
    end

    context "when actions contain numeric sell fractions" do
      let(:sell_action_json) do
        [
          { "c" => "buyCount>0", "a" => ["sell 0.25"] }
        ].to_json
      end

      it "passes validation for fractional sells" do
        result = described_class.call(sell_action_json)
        expect(result[:valid]).to be(true)
        compressed = JSON.parse(result[:compressed]).first["a"].first
        expect(compressed).to eq("sell 0.25")
      end
    end

    context "rejects legacy action formats" do
      let(:legacy_buy_json) { [{ "c" => "bcn==0", "a" => ["buy init"] }].to_json }
      let(:legacy_sell_json) { [{ "c" => "bcn>0", "a" => ["sell bta*0.25"] }].to_json }

      it "rejects buy init" do
        result = described_class.call(legacy_buy_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors].first).to match(/Unknown action 'buy init'/)
      end

      it "rejects sell bta* syntax" do
        result = described_class.call(legacy_sell_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors].first).to match(/invalid sell syntax/i)
      end
    end

    context "rejects duplicates" do
      it "returns error when same compressed JSON exists" do
        chain = Chain.create!(name: "base_mainnet", native_chain_id: "8453")

        first = described_class.call(valid_strategy_json)
        compressed = first[:compressed]

        Strategy.create!(chain: chain, strategy_json: compressed)

        result = described_class.call(valid_strategy_json)
        expect(result[:valid]).to be(false)
        expect(result[:errors].first).to match(/Duplicate strategy already exists/)
      end
    end
  end

  describe "field mapping round-trip integrity" do
    let(:valid_fields) { Gammascript::Constants::VALID_FIELDS }

    it "maps every 3-char field to a human-readable name and back" do
      short_keys = valid_fields.keys.select { |k| k.length == 3 }
      short_keys.each do |short|
        human = valid_fields[short]
        expect(valid_fields[human]).to eq(short), "Expected #{human} → #{short}"
      end
    end

    it "ensures all human-readable fields have matching 3-char codes" do
      human_keys = valid_fields.keys.reject { |k| k.length == 3 }
      human_keys.each do |human|
        short = valid_fields[human]
        expect(valid_fields[short]).to eq(human), "Expected #{short} → #{human}"
      end
    end
  end
end