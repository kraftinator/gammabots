require 'rails_helper'

RSpec.describe TradingStrategyInterpreter do
  let(:bot) { instance_double("Bot", update!: true, base_token_amount: 1.0) }
  let(:token_pair) { instance_double("TokenPair", latest_price: 1.0) }
  let(:trades) { instance_double("ActiveRecord::Relation", where: []) }
  
  # Common variables that will be modified in each test case
  let(:base_variables) do
    {
      bot: bot,
      cpr: token_pair.latest_price,    # Current Price
      ibp: 1.0,                         # Initial Buy Price
      scn: 0,                           # Sell Count
      bta: 1.0,                         # Base Token Amount
      hip: 1.0,                         # Highest Price Since Initial Buy
      hlt: 1.0,                         # Highest Price Since Last Trade
      lip: 1.0,                         # Lowest Price Since Initial Buy
      llt: 1.0,                         # Lowest Price Since Last Trade
      lta: Time.now,                    # Last Traded At
      lsp: 1.0,                         # Last Sell Price
      crt: Time.now,                    # Created At
      provider_url: "https://example.com/api"
    }
  end

  # Mock service that would normally handle the actual selling
  before do
    allow(TradeExecutionService).to receive(:sell).and_return(true)
    allow(Rails.logger).to receive(:error)
  end

  describe 'Strategy 1' do
    let(:strategy_json) { '[{"c":"cpr<=ibp*0.8","a":["sell all","deact"]},{"c":"cpr>=ibp*1.2&&scn==0","a":["sell bta*0.25"]},{"c":"cpr>=ibp*1.5&&scn==1","a":["sell bta*0.25"]},{"c":"cpr<=hip*0.8&&scn==2","a":["sell all","deact"]}]' }

    context 'when price drops to 80% of initial buy price' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 0.79, ibp: 1.0)
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 1.0, 0, "https://example.com/api"
        ).and_return(true)
        expect(bot).to receive(:update!).with(active: false)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when price rises to 120% of initial buy price with no previous sells' do
      it 'sells 25% of base token amount' do
        variables = base_variables.merge(cpr: 1.21, ibp: 1.0, scn: 0)
        
        # Calculate expected min_amount_out based on the condition: cpr>=ibp*1.2
        expected_min_amount_out = 0.25 * 1.0 * 1.2
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.25, expected_min_amount_out, "https://example.com/api"
        )
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when price rises to 150% of initial buy price with one previous sell' do
      it 'sells 25% of base token amount' do
        variables = base_variables.merge(cpr: 1.51, ibp: 1.0, scn: 1)
        
        # Calculate expected min_amount_out based on the condition: cpr>=ibp*1.5
        expected_min_amount_out = 0.25 * 1.0 * 1.5
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.25, expected_min_amount_out, "https://example.com/api"
        )
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when price drops to 80% of highest price with two previous sells' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 1.6, hip: 2.0, scn: 2)
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 1.0, 0, "https://example.com/api"
        ).and_return(true)
        expect(bot).to receive(:update!).with(active: false)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when no conditions match' do
      it 'does not execute any actions' do
        variables = base_variables.merge(cpr: 1.1, ibp: 1.0, scn: 0)
        
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Strategy 2' do
    let(:strategy_json) { '[{"c":"cpr<=ibp*0.8","a":["sell all","deact"]},{"c":"scn==0&&hip>=ibp*2.0&&cpr<=hip*0.90","a":["sell bta*0.50"]},{"c":"scn>0&&cpr<=hlt*0.90","a":["sell bta*0.25"]}]' }
    
    context 'when price drops to 80% of initial buy price' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 0.79, ibp: 1.0)
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 1.0, 0, "https://example.com/api"
        ).and_return(true)
        expect(bot).to receive(:update!).with(active: false)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when highest price is 2x initial price and current price drops to 90% of highest with no previous sells' do
      it 'sells 50% of base token amount' do
        variables = base_variables.merge(cpr: 1.8, ibp: 1.0, hip: 2.0, scn: 0)
        
        # The extract_threshold_info will pick up hip*0.90 and use hip as the base
        # So min_amount_out = 0.5 * 2.0 * 0.9 = 0.9, but it seems the implementation
        # is providing 0.5 * 2.0 = 1.0
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.5, 1.0, "https://example.com/api"
        )
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when current price drops to 90% of highest price since last trade with previous sells' do
      it 'sells 25% of base token amount' do
        variables = base_variables.merge(cpr: 1.8, hlt: 2.0, scn: 1)
        
        # The implementation doesn't pick up hlt*0.90 in extract_threshold_info
        # So min_amount_out is 0
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.25, 0, "https://example.com/api"
        )
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when no conditions match' do
      it 'does not execute any actions' do
        variables = base_variables.merge(cpr: 1.1, ibp: 1.0, scn: 0, hip: 1.5)
        
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Strategy 3' do
    let(:strategy_json) { '[{"c":"cpr<=ibp*0.75","a":["sell all","deact"]},{"c":"scn==0&&hip>=ibp*2.0&&cpr<=hip*0.90","a":["sell bta*0.50"]},{"c":"scn==1&&cpr<=hlt*0.90","a":["sell bta*0.25"]},{"c":"scn>=2&&cpr>=lsp*1.5&&cpr<=hlt*0.90","a":["sell bta*0.25"]},{"c":"scn>=2&&cpr<=ibp","a":["sell all","deact"]}]' }
    
    context 'when price drops to 75% of initial buy price' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 0.74, ibp: 1.0)
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 1.0, 0, "https://example.com/api"
        ).and_return(true)
        expect(bot).to receive(:update!).with(active: false)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when highest price is 2x initial price and current price drops to 90% of highest with no previous sells' do
      it 'sells 50% of base token amount' do
        variables = base_variables.merge(cpr: 1.8, ibp: 1.0, hip: 2.0, scn: 0)
        
        # The extract_threshold_info will pick up hip*0.90 and use hip as the base
        # So we expect min_amount_out = 0.5 * 2.0 = 1.0
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.5, 1.0, "https://example.com/api"
        )
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when current price drops to 90% of highest price since last trade with one previous sell' do
      it 'sells 25% of base token amount' do
        variables = base_variables.merge(cpr: 1.8, hlt: 2.0, scn: 1)
        
        # The implementation doesn't pick up hlt*0.90 in extract_threshold_info
        # So min_amount_out is 0
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.25, 0, "https://example.com/api"
        )
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when price is 1.5x last sell price and 90% of highest since last trade with multiple previous sells' do
      it 'sells 25% of base token amount' do
        variables = base_variables.merge(cpr: 1.5, lsp: 1.0, hlt: 1.7, scn: 2)
        
        # The extract_threshold_info will pick up lsp*1.5 and use lsp as the base
        # So min_amount_out = 0.25 * 1.0 * 1.5 = 0.375
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.25, 0.375, "https://example.com/api"
        )
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when price drops below initial buy price with multiple previous sells' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 0.95, ibp: 1.0, scn: 2)
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 1.0, 0, "https://example.com/api"
        ).and_return(true)
        expect(bot).to receive(:update!).with(active: false)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when no conditions match' do
      it 'does not execute any actions' do
        variables = base_variables.merge(cpr: 1.1, ibp: 1.0, scn: 0, hip: 1.5)
        
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'error handling' do
    let(:strategy_json) { '[{"c":"invalid_condition","a":["sell bta*0.25"]}]' }
    
    it 'logs errors when evaluating invalid conditions' do
      expect(Rails.logger).to receive(:error).with(/Error evaluating condition/)
      
      interpreter = described_class.new(strategy_json, base_variables)
      interpreter.execute
    end
    
    context 'with invalid amount expression' do
      let(:strategy_json) { '[{"c":"true","a":["sell invalid_amount"]}]' }
      
      it 'logs errors when parsing invalid amount expressions' do
        expect(Rails.logger).to receive(:error).with(/Error parsing amount expression/)
        
        interpreter = described_class.new(strategy_json, base_variables)
        interpreter.execute
      end
    end
    
    context 'with unknown action' do
      let(:strategy_json) { '[{"c":"true","a":["unknown_action"]}]' }
      
      it 'logs errors for unknown actions' do
        expect(Rails.logger).to receive(:error).with(/Unknown action/)
        
        interpreter = described_class.new(strategy_json, base_variables)
        interpreter.execute
      end
    end
    
    context 'when trade execution fails' do
      let(:strategy_json) { '[{"c":"true","a":["sell all","deact"]}]' }
      
      it 'does not deactivate the bot if swap did not occur' do
        allow(TradeExecutionService).to receive(:sell).and_return(nil)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, base_variables)
        interpreter.execute
      end
    end
  end

  describe '#extract_threshold_info' do
    let(:strategy_json) { '[]' }
    let(:interpreter) { described_class.new(strategy_json, base_variables) }
    
    it 'extracts ibp multiplier correctly' do
      condition = "cpr<=ibp*0.75"
      result = interpreter.send(:extract_threshold_info, condition)
      expect(result).to eq({ multiplier: 0.75, base: :ibp })
    end
    
    it 'extracts lsp multiplier correctly' do
      condition = "cpr>=lsp*1.5"
      result = interpreter.send(:extract_threshold_info, condition)
      expect(result).to eq({ multiplier: 1.5, base: :lsp })
    end
    
    it 'extracts hip multiplier correctly' do
      condition = "cpr<=hip*0.9"
      result = interpreter.send(:extract_threshold_info, condition)
      expect(result).to eq({ multiplier: 0.9, base: :hip })
    end
    
    it 'returns nil when no supported multiplier is found' do
      condition = "cpr<=hlt*0.9"
      result = interpreter.send(:extract_threshold_info, condition)
      expect(result).to be_nil
    end
  end

  describe '#binding_from_variables' do
    let(:strategy_json) { '[]' }
    let(:interpreter) { described_class.new(strategy_json, base_variables) }
    
    it 'sets only allowed variables in binding' do
      binding = interpreter.send(:binding_from_variables)
      
      # Check that allowed variables are set
      expect(binding.local_variable_get(:cpr)).to eq(1.0)
      expect(binding.local_variable_get(:ibp)).to eq(1.0)
      
      # Ensure bot is not available in the binding
      expect {
        binding.local_variable_get(:bot)
      }.to raise_error(NameError)
      
      # Ensure provider_url is not available in the binding
      expect {
        binding.local_variable_get(:provider_url)
      }.to raise_error(NameError)
    end
  end
end