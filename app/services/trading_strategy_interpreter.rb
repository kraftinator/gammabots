class TradingStrategyInterpreter
  def initialize(strategy_json, variables)
    # Parse the JSON strategy into an array of rule hashes.
    @rules = JSON.parse(strategy_json)
    # Variables is a hash mapping variable names (as symbols or strings) to their current values.
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

  # Evaluates a condition string (e.g. "cp>=ib*1.05&&sc==0")
  def evaluate_condition(condition_str)
    eval(condition_str, binding_from_variables)
  rescue Exception => e
    Rails.logger.error "Error evaluating condition '#{condition_str}': #{e.message}"
    false
  end

  # Processes each action in the actions array.
  # For a sell action, it calculates the min_amount_out based on the condition.
  def execute_actions(rule, actions)
    actions.each do |action_str|
      case action_str
      when /\Asell\s+(.*)\z/i
        amount_expr = Regexp.last_match(1).strip
        sell_amount = parse_amount(amount_expr)
        threshold_info = extract_threshold_info(rule['c'])
        if threshold_info
          base_value = @variables[threshold_info[:base]]
          target_price = base_value * threshold_info[:multiplier]
          min_amount_out = sell_amount * target_price
        else
          min_amount_out = 0
        end
        TradeExecutionService.sell(@variables[:bot], sell_amount, min_amount_out, @variables[:provider_url])
      when /\Adeact\z/i
        @variables[:bot].update!(active: false)
      else
        Rails.logger.error "Unknown action: #{action_str}"
      end
    end
  end

  # Parses the sell amount from an expression like "bta*0.25" or "all"
  def parse_amount(expression)
    if expression == "all"
      @variables[:bot].base_token_amount
    else
      eval(expression, binding_from_variables)
    end
  rescue Exception => e
    Rails.logger.error "Error parsing amount expression '#{expression}': #{e.message}"
    0
  end

  # Extracts the threshold multiplier and base key from the condition string.
  # It first looks for an "ib*" clause and, if found, returns that multiplier using ib as base.
  # Otherwise, it checks for a "hib*" clause.
  def extract_threshold_info(condition_str)
    if condition_str =~ /\bib\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :ib }
    elsif condition_str =~ /\bhib\*(\d*\.?\d+)/
      { multiplier: $1.to_f, base: :hib }
    else
      nil
    end
  end

  # Constructs a binding with all variables from @variables.
  def binding_from_variables
    b = binding
    @variables.each { |key, value| b.local_variable_set(key.to_sym, value) }
    b
  end
end
