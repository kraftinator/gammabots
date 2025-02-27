class TradingStrategyInterpreter
  def initialize(strategy_json, variables)
    # Parse the JSON strategy into an array of rule hashes.
    @rules = JSON.parse(strategy_json)
    # @variables is a hash mapping fixed three-letter keys to their current values.
    @variables = variables
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
  # For a sell action, it calculates the min_amount_out based on the condition,
  # except when the sell action is "sell all" (liquidation) where we set it to 0.
  # It also only deactivates the bot if a swap occurred.
  def execute_actions(rule, actions)
    swap_executed = false
    actions.each do |action_str|
      case action_str
      when /\Asell\s+(.*)\z/i
        amount_expr = Regexp.last_match(1).strip
        sell_amount = parse_amount(amount_expr)
        if amount_expr.downcase == "all"
          # For liquidation events ("sell all"), we ignore slippage and set min_amount_out to 0.
          min_amount_out = 0
        else
          threshold_info = extract_threshold_info(rule['c'])
          if threshold_info
            base_value = @variables[threshold_info[:base]]
            target_price = base_value * threshold_info[:multiplier]
            min_amount_out = sell_amount * target_price
          else
            min_amount_out = 0
          end
        end
        result = TradeExecutionService.sell(@variables[:bot], sell_amount, min_amount_out, @variables[:provider_url])
        swap_executed = true if result.present?
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
  # It first looks for an "ibp*" clause and, if found, returns that multiplier using ibp as base.
  # Otherwise, it checks for a "hip*" clause.
  def extract_threshold_info(condition_str)
    if condition_str =~ /\bibp\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :ibp }
    elsif condition_str =~ /\blsp\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :lsp }
    elsif condition_str =~ /\bhip\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :hip }
    else
      nil
    end
  end
  
  #def extract_threshold_info(condition_str)
  #  if condition_str =~ /\bibp\*(\d*\.?\d+)/
  #    { multiplier: $1.to_f, base: :ibp }
  #  elsif condition_str =~ /\bhip\*(\d*\.?\d+)/
  #    { multiplier: $1.to_f, base: :hip }
  #  else
  #    nil
  #  end
  #end

  # Constructs a binding with only the strategy variables.
  def binding_from_variables
    b = binding
    allowed_keys = [:cpr, :ibp, :scn, :bta, :hip, :hlt, :lip, :llt, :lta, :lsp, :crt]
    @variables.each do |key, value|
      b.local_variable_set(key.to_sym, value) if allowed_keys.include?(key.to_sym)
    end
    b
  end
end
