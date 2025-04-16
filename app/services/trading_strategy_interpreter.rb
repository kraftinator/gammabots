class TradingStrategyInterpreter
  def initialize(strategy_json, variables)
    # Parse the JSON strategy into an array of rule hashes.
    @rules = JSON.parse(strategy_json)
    # @variables is a hash mapping fixed three-letter keys to their current values.
    @variables = variables
    
    # Ensure lta is properly converted to minutes since last trade
    if @variables[:lta].is_a?(Time) || @variables[:lta].is_a?(ActiveSupport::TimeWithZone)
      @variables[:lta] = ((Time.now - @variables[:lta]) / 60).to_i
    elsif @variables[:lta].nil?
      @variables[:lta] = Float::INFINITY
    end

    # Ensure lba is properly converted to minutes since last trade
    if @variables[:lba].is_a?(Time) || @variables[:lba].is_a?(ActiveSupport::TimeWithZone)
      @variables[:lba] = ((Time.now - @variables[:lba]) / 60).to_i
    elsif @variables[:lba].nil?
      @variables[:lba] = Float::INFINITY
    end
    
    # Also ensure crt is converted to minutes
    if @variables[:crt].is_a?(Time) || @variables[:crt].is_a?(ActiveSupport::TimeWithZone)
      @variables[:crt] = ((Time.now - @variables[:crt]) / 60).to_i
    elsif @variables[:crt].nil?
      @variables[:crt] = Float::INFINITY
    end
  end

  def execute
    puts "***** Calling TradingStrategyInterpreter"
    @rules.each do |rule|
      if evaluate_condition(rule['c'])
        execute_actions(rule, rule['a'])
        # Stop processing further rules after the first match.
        return
      end
    end
  end

  private

  # Evaluates a condition string (e.g. "cpr>=ibp*1.05&&scn==0")
  def evaluate_condition(condition_str)
    eval(condition_str, binding_from_variables)
  rescue Exception => e
    Rails.logger.error "Error evaluating condition '#{condition_str}': #{e.message}"
    false
  end

  # Processes each action in the actions array.
  def execute_actions(rule, actions)
    swap_executed = false
    actions.each do |action_str|
      case action_str
      when /\Abuy init\z/i
        # For "buy init", execute initial buy
        result = TradeExecutionService.buy(@variables[:bot], @variables[:bot].min_amount_out_for_initial_buy, @variables[:provider_url])
        swap_executed = true if result.present?
      when /\Asell\s+(.*)\z/i
        amount_expr = Regexp.last_match(1).strip
        sell_amount = parse_amount(amount_expr)
        if amount_expr.downcase == "all"
          # For liquidation events ("sell all"), we ignore slippage and set min_amount_out to 0.
          min_amount_out = 0
        else
            base_value = @variables[:cpr]            
            safety_factor = 0.95
            min_amount_out = sell_amount * base_value * safety_factor

=begin
          threshold_info = extract_threshold_info(rule['c'])
          if threshold_info
            #base_value = @variables[threshold_info[:base]]
            #target_price = base_value * threshold_info[:multiplier]
            #min_amount_out = sell_amount * target_price

            # Use current price instead of the threshold's base value
            base_value = @variables[:cpr]            
            safety_factor = 0.95
            min_amount_out = sell_amount * base_value * safety_factor
            
            puts "***** Threshold Info *****"
            puts "action_str: #{action_str}"
            #puts "base_value: #{base_value.to_s}"
            #puts "multiplier: #{threshold_info[:multiplier].to_s}"
            #puts "sell_amount: #{sell_amount.to_s}"
            #puts "target_price: #{target_price.to_s}"
            puts "min_amount_out: #{min_amount_out.to_s}"
            #puts "new min_amount_out: #{sell_amount * @variables[:cpr]  * 0.95}"
          else
            min_amount_out = 0
          end
=end

        end
        result = TradeExecutionService.sell(@variables[:bot], sell_amount, min_amount_out, @variables[:provider_url])
        swap_executed = true if result.present?
      when /\Adeact\s+force\z/i
        # Force deactivation regardless of swap status
        puts "Force deactivating bot"
        @variables[:bot].update!(active: false)
        puts "Bot force deactivated"
      when /\Adeact\z/i
        if swap_executed
          puts "Deactivating bot"
          @variables[:bot].update!(active: false)
        else
          puts "Swap did not occur; bot remains active"
        end
      else
        Rails.logger.error "Unknown action: #{action_str}"
      end
    end
  end

  # Parses the sell amount from an expression like "bta*0.25" or "all"
  def parse_amount(expression)
    if expression.downcase == "all"
      @variables[:bot].base_token_amount
    else
      eval(expression, binding_from_variables)
    end
  rescue Exception => e
    Rails.logger.error "Error parsing amount expression '#{expression}': #{e.message}"
    0
  end

  # Extracts the threshold multiplier and base key from the condition string.
  def extract_threshold_info(condition_str)
    if condition_str =~ /\bibp\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :ibp }
    elsif condition_str =~ /\blsp\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :lsp }
    elsif condition_str =~ /\bhip\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :hip }
    elsif condition_str =~ /\blps\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :lps }
    else
      nil
    end
  end

  # Constructs a binding with only the strategy variables.
  def binding_from_variables
    b = binding
    allowed_keys = [:cpr, :ibp, :scn, :bcn, :bta, :hip, :hlt, :lip, :llt, :lta, :lba, :lsp, :lps, :crt, :cma, :lmc, :hma, :lma, :hmt, :lmt, :lmi]
    @variables.each do |key, value|
      b.local_variable_set(key.to_sym, value) if allowed_keys.include?(key.to_sym)
    end
    b
  end
end