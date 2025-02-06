class TradingStrategyInterpreter
  def initialize(strategy_json, variables)
    # Parse the JSON strategy into an array of rule hashes.
    @rules = JSON.parse(strategy_json)
    # Variables is a hash mapping variable names (as symbols or strings) to their current values.
    @variables = variables
  end

  def execute
    @rules.each do |rule|
      # Evaluate the rule's condition.
      if evaluate_condition(rule['c'])
        # If the condition is met, execute all the actions in order.
        execute_actions(rule['a'])
        # Stop processing further rules after the first match.
        return
      end
    end
  end

  private

  # Evaluates a condition string (for example: "cp<=ib*0.8")
  def evaluate_condition(condition_str)
    eval(condition_str, binding_from_variables)
  rescue Exception => e
    Rails.logger.error "Error evaluating condition '#{condition_str}': #{e.message}"
    false
  end

  # Processes each action in the actions array.
  # For example, an action might be "sell all" or "sell ba*0.25" or "deact"
  def execute_actions(actions)
    actions.each do |action_str|
      case action_str
      when /\Asell\s+(.*)\z/i
        # Extract the expression after "sell"
        amount_expr = Regexp.last_match(1).strip
        amount = parse_amount(amount_expr)
        # Call your TradeExecutionService (assuming it exists)
        #TradeExecutionService.sell(@variables[:bot], amount, @variables[:provider_url])
        puts "Call TradeExecuationService"
      when /\Adeact\z/i
        # Deactivate the bot
        @variables[:bot].update!(active: false)
      else
        Rails.logger.error "Unknown action: #{action_str}"
      end
    end
  end

  # Parses the amount expression used in sell actions.
  # If the expression is "all", return the entire base token amount.
  # Otherwise, evaluate the expression (e.g., "ba*0.25").
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

  # Constructs a binding with all variables from @variables.
  # This allows eval to resolve variable names like cp, ib, st, etc.
  def binding_from_variables
    b = binding
    @variables.each do |key, value|
      # Use the key as the variable name. It can be a symbol or a string.
      b.local_variable_set(key.to_sym, value)
    end
    b
  end
end
