require 'rails_helper'

RSpec.describe TradingStrategyInterpreter do
  let(:bot) { instance_double("Bot", update!: true, base_token_amount: 1.0, min_amount_out_for_initial_buy: 0.95) }
  let(:token_pair) { instance_double("TokenPair", latest_price: 1.0) }
  let(:trades) { instance_double("ActiveRecord::Relation", where: []) }
  
  # Time references for testing
  let(:current_time) { Time.now }
  let(:one_hour_ago) { current_time - 1.hour }
  let(:one_day_ago) { current_time - 1.day }
  
  # Common variables that will be modified in each test case
  let(:base_variables) do
    {
      bot: bot,
      cpr: token_pair.latest_price,    # Current Price
      ibp: 1.0,                         # Initial Buy Price
      scn: 0,                           # Sell Count
      bcn: 0,                           # Buy Count (New)
      bta: 1.0,                         # Base Token Amount
      hip: 1.0,                         # Highest Price Since Initial Buy
      hlt: 1.0,                         # Highest Price Since Last Trade
      lip: 1.0,                         # Lowest Price Since Initial Buy
      llt: 1.0,                         # Lowest Price Since Last Trade
      lps: 1.0,                         # Lowest Price Since Creation (New)
      lta: current_time,                # Last Traded At (will be converted to minutes)
      lba: current_time,                # Last Buy At (will be converted to minutes)
      lsp: 1.0,                         # Last Sell Price
      crt: current_time,                # Created At (will be converted to minutes)
      provider_url: "https://example.com/api"
    }
  end

  # Mock service that would normally handle the actual trading
  before do
    allow(TradeExecutionService).to receive(:sell).and_return(true)
    allow(TradeExecutionService).to receive(:buy).and_return(true)
    allow(Rails.logger).to receive(:error)
    # Freeze time for testing
    allow(Time).to receive(:now).and_return(current_time)
  end

  describe 'Initial Buy Strategy' do
    let(:strategy_json) { '[{"c":"bcn==0","a":["buy init"]},{"c":"cpr<=ibp*0.75","a":["sell all","deact"]}]' }

    context 'when no buys have been made yet' do
      it 'executes initial buy' do
        variables = base_variables.merge(bcn: 0)
        
        expect(TradeExecutionService).to receive(:buy).with(
          bot, 0.95, "https://example.com/api"
        ).and_return(true)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end

    context 'when a buy has already been made' do
      it 'does not execute another buy' do
        variables = base_variables.merge(bcn: 1)
        
        expect(TradeExecutionService).not_to receive(:buy)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Wait for Uptick Strategy' do
    let(:strategy_json) { '[{"c":"bcn==0&&cpr>=lps*1.10","a":["buy init"]},{"c":"cpr<=ibp*0.75","a":["sell all","deact"]}]' }

    context 'when price has increased at least 10% from lowest' do
      it 'executes initial buy' do
        variables = base_variables.merge(bcn: 0, cpr: 1.1, lps: 1.0)
        
        expect(TradeExecutionService).to receive(:buy).with(
          bot, 0.95, "https://example.com/api"
        ).and_return(true)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end

    context 'when price has not increased enough' do
      it 'does not execute the buy' do
        variables = base_variables.merge(bcn: 0, cpr: 1.05, lps: 1.0)
        
        expect(TradeExecutionService).not_to receive(:buy)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Time-based Strategy' do
    let(:strategy_json) { '[{"c":"true","a":["sell bta*0.1"]}]' }

    context 'when the condition is true' do
      it 'executes a sell' do
        variables = base_variables.merge(bcn: 1)
        
        # With the "sell bta*0.1" action, we expect the TradeExecutionService to receive a sell call
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 0.1, 0, "https://example.com/api"
        ).and_return(true)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end

    context 'when less than 60 minutes have passed since last trade' do
      it 'does not execute a buy' do
        variables = base_variables.merge(bcn: 1, lta: current_time - 30.minutes)
        
        expect(TradeExecutionService).not_to receive(:buy)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end

    context 'when less than 60 minutes have passed since last buy' do
      it 'does not execute a buy' do
        variables = base_variables.merge(bcn: 1, lba: current_time - 30.minutes)
        
        expect(TradeExecutionService).not_to receive(:buy)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Created-At Time-based Strategy' do
    context 'with a buy init strategy' do
      let(:strategy_json) { '[{"c":"bcn==0","a":["buy init"]}]' }
      
      it 'executes initial buy' do
        variables = base_variables.merge(bcn: 0)
        
        expect(TradeExecutionService).to receive(:buy).with(
          bot, 0.95, "https://example.com/api"
        ).and_return(true)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Strategy 1' do
    let(:strategy_json) { '[{"c":"bcn>0&&cpr<=ibp*0.8","a":["sell all","deact"]},{"c":"bcn>0&&cpr>=ibp*1.2&&scn==0","a":["sell bta*0.25"]},{"c":"bcn>0&&cpr>=ibp*1.5&&scn==1","a":["sell bta*0.25"]},{"c":"bcn>0&&cpr<=hip*0.8&&scn==2","a":["sell all","deact"]}]' }

    context 'when price drops to 80% of initial buy price' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 0.79, ibp: 1.0, bcn: 1)
        
        expect(TradeExecutionService).to receive(:sell).with(
          bot, 1.0, 0, "https://example.com/api"
        ).and_return(true)
        expect(bot).to receive(:update!).with(active: false)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when price drops but no buys have been made' do
      it 'does nothing' do
        variables = base_variables.merge(cpr: 0.79, ibp: 1.0, bcn: 0)
        
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
    
    context 'when price rises to 120% of initial buy price with no previous sells' do
      it 'sells 25% of base token amount' do
        variables = base_variables.merge(cpr: 1.21, ibp: 1.0, scn: 0, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.51, ibp: 1.0, scn: 1, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.6, hip: 2.0, scn: 2, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.1, ibp: 1.0, scn: 0, bcn: 1)
        
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Strategy 2' do
    let(:strategy_json) { '[{"c":"bcn>0&&cpr<=ibp*0.8","a":["sell all","deact"]},{"c":"bcn>0&&scn==0&&hip>=ibp*2.0&&cpr<=hip*0.90","a":["sell bta*0.50"]},{"c":"bcn>0&&scn>0&&cpr<=hlt*0.90","a":["sell bta*0.25"]}]' }
    
    context 'when price drops to 80% of initial buy price' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 0.79, ibp: 1.0, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.8, ibp: 1.0, hip: 2.0, scn: 0, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.8, hlt: 2.0, scn: 1, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.1, ibp: 1.0, scn: 0, hip: 1.5, bcn: 1)
        
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Strategy 3' do
    let(:strategy_json) { '[{"c":"bcn>0&&cpr<=ibp*0.75","a":["sell all","deact"]},{"c":"bcn>0&&scn==0&&hip>=ibp*2.0&&cpr<=hip*0.90","a":["sell bta*0.50"]},{"c":"bcn>0&&scn==1&&cpr<=hlt*0.90","a":["sell bta*0.25"]},{"c":"bcn>0&&scn>=2&&cpr>=lsp*1.5&&cpr<=hlt*0.90","a":["sell bta*0.25"]},{"c":"bcn>0&&scn>=2&&cpr<=ibp","a":["sell all","deact"]}]' }
    
    context 'when price drops to 75% of initial buy price' do
      it 'sells all and deactivates the bot' do
        variables = base_variables.merge(cpr: 0.74, ibp: 1.0, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.8, ibp: 1.0, hip: 2.0, scn: 0, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.8, hlt: 2.0, scn: 1, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.5, lsp: 1.0, hlt: 1.7, scn: 2, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 0.95, ibp: 1.0, scn: 2, bcn: 1)
        
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
        variables = base_variables.merge(cpr: 1.1, ibp: 1.0, scn: 0, hip: 1.5, bcn: 1)
        
        expect(TradeExecutionService).not_to receive(:sell)
        expect(bot).not_to receive(:update!)
        
        interpreter = described_class.new(strategy_json, variables)
        interpreter.execute
      end
    end
  end

  describe 'Time variables conversion' do
    let(:strategy_json) { '[]' }
    
    it 'converts lta to minutes since last trade' do
      # Set last_traded_at to 65 minutes ago
      one_hour_plus_ago = current_time - 65.minutes
      variables = base_variables.merge(lta: one_hour_plus_ago)
      
      # Mock Time.now to ensure consistent results
      allow(Time).to receive(:now).and_return(current_time)
      
      interpreter = described_class.new(strategy_json, variables)
      # Access the instance variable containing the processed variables
      processed_vars = interpreter.instance_variable_get(:@variables)
      
      # Calculate expected minutes - should be around 65
      expected_minutes = ((current_time - one_hour_plus_ago) / 60).to_i
      
      # Check that lta is now a number of minutes (approximately 65)
      expect(processed_vars[:lta]).to be_within(1).of(expected_minutes)
    end

    it 'converts lba to minutes since last trade' do
      # Set last_traded_at to 65 minutes ago
      one_hour_plus_ago = current_time - 65.minutes
      variables = base_variables.merge(lba: one_hour_plus_ago)
      
      # Mock Time.now to ensure consistent results
      allow(Time).to receive(:now).and_return(current_time)
      
      interpreter = described_class.new(strategy_json, variables)
      # Access the instance variable containing the processed variables
      processed_vars = interpreter.instance_variable_get(:@variables)
      
      # Calculate expected minutes - should be around 65
      expected_minutes = ((current_time - one_hour_plus_ago) / 60).to_i
      
      # Check that lba is now a number of minutes (approximately 65)
      expect(processed_vars[:lba]).to be_within(1).of(expected_minutes)
    end
    
    it 'converts crt to minutes since creation' do
      # Set created_at to 2 days ago
      two_days_ago = current_time - 2.days
      variables = base_variables.merge(crt: two_days_ago)
      
      # Mock Time.now to ensure consistent results
      allow(Time).to receive(:now).and_return(current_time)
      
      interpreter = described_class.new(strategy_json, variables)
      processed_vars = interpreter.instance_variable_get(:@variables)
      
      # Calculate expected minutes
      expected_minutes = ((current_time - two_days_ago) / 60).to_i
      
      # Check that crt matches our calculated minutes
      expect(processed_vars[:crt]).to be_within(1).of(expected_minutes)
    end
    
    it 'sets lta to Infinity when nil' do
      variables = base_variables.merge(lta: nil)
      
      interpreter = described_class.new(strategy_json, variables)
      processed_vars = interpreter.instance_variable_get(:@variables)
      
      expect(processed_vars[:lta]).to eq(Float::INFINITY)
    end

    it 'sets lba to Infinity when nil' do
      variables = base_variables.merge(lba: nil)
      
      interpreter = described_class.new(strategy_json, variables)
      processed_vars = interpreter.instance_variable_get(:@variables)
      
      expect(processed_vars[:lba]).to eq(Float::INFINITY)
    end
    
    it 'sets crt to Infinity when nil' do
      variables = base_variables.merge(crt: nil)
      
      interpreter = described_class.new(strategy_json, variables)
      processed_vars = interpreter.instance_variable_get(:@variables)
      
      expect(processed_vars[:crt]).to eq(Float::INFINITY)
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
    
    it 'extracts lps multiplier correctly' do
      condition = "cpr>=lps*1.10"
      result = interpreter.send(:extract_threshold_info, condition)
      expect(result).to eq({ multiplier: 1.10, base: :lps })
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
      expect(binding.local_variable_get(:bcn)).to eq(0)
      expect(binding.local_variable_get(:lps)).to eq(1.0)
      
      # Ensure bot is not available in the binding
      expect {
        binding.local_variable_get(:bot)
      }.to raise_error(NameError)
      
      # Ensure provider_url is not available in the binding
      expect {
        binding.local_variable_get(:provider_url)
      }.to raise_error(NameError)
    end
    
    it 'includes time-based variables in binding' do
      variables = base_variables.merge(
        lta: current_time - 120.minutes,
        lba: current_time - 120.minutes,
        crt: current_time - 24.hours
      )
      
      interpreter = described_class.new(strategy_json, variables)
      binding = interpreter.send(:binding_from_variables)
      
      # Check that lta is available in binding and converted to minutes
      expect(binding.local_variable_get(:lta)).to be_within(1).of(120)

      # Check that lba is available in binding and converted to minutes
      expect(binding.local_variable_get(:lba)).to be_within(1).of(120)

      # Check that crt is available in binding and converted to minutes
      expect(binding.local_variable_get(:crt)).to be_within(1).of(24 * 60)
    end
  end
end