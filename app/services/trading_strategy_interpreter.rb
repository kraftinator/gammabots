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
    @rules.each_with_index do |rule, idx|
      if evaluate_condition(rule['c'])
        execute_actions(rule, rule['a'], idx + 1)
        return
      end
    end
  end

  private

  # Evaluates a condition string (e.g. "cpr>=ibp*1.05&&scn==0")
  def evaluate_condition(condition_str)
    eval(condition_str, binding_from_variables)
  rescue Exception => e
    Rails.logger.error "Bot #{@variables[:bot].id}: Error evaluating condition '#{condition_str}': #{e.message}"
    false
  end

  # Processes each action in the actions array.
  def execute_actions(rule, actions, step)
    swap_executed = false
    actions.each do |action_str|
      case action_str
      when /\Askip\z/i
        # intentional no-op: skip this cycle
        Rails.logger.info "Bot #{@variables[:bot].id}: skipping trades for this cycle"
        return
      #when /\Abuy init\z/i
      when /\Abuy(\s+init)?\z/i
        # For "buy", execute initial buy
        result = TradeExecutionService.buy(@variables.merge({ step: step }))
        swap_executed = true if result.present?
      when /\Asell\s+(.*)\z/i
        arg = Regexp.last_match(1).strip.downcase
        fraction =
          if arg == "all"
            1.0
          elsif arg.start_with?("bta*")
            arg.split("*").last.to_f
          else
            arg.to_f
          end

        if fraction <= 0 || fraction > 1
          Rails.logger.error "Invalid sell fraction '#{arg}' for bot #{@variables[:bot].id}"
          next
        end

        sell_amount = @variables[:bot].current_cycle.base_token_amount * fraction
        min_amount_out = fraction == 1 ? 0 : sell_amount * @variables[:cpr] * 0.95

        result = TradeExecutionService.sell(@variables.merge({ step: step }), sell_amount, min_amount_out)
        swap_executed = true if result.present?
      when /\Adeact\s+force\z/i
        # 'deact force' is a legacy action
        @variables[:bot].forced_deactivate
        Rails.logger.info "Bot #{@variables[:bot].id}: Forced deactivated."
      when /\Adeact\z/i
        has_bought = (@variables[:bcn] || 0).to_i > 0
        if has_bought
          if swap_executed
            @variables[:bot].deactivate
            Rails.logger.info "Bot #{@variables[:bot].id}: Deactivated."
          else
            Rails.logger.info "Bot #{@variables[:bot].id}: Swap did not occur; bot remains active."
          end
        else
          @variables[:bot].forced_deactivate
          Rails.logger.info "Bot #{@variables[:bot].id}: Forced deactivated."
        end        
      when /\Areset\z/i
        if swap_executed
          puts "Resetting bot"
          @variables[:bot].reset
        else
          puts "Swap did not occur; no reset"
        end
      else
        Rails.logger.error "Unknown action: #{action_str}"
      end
    end
  end

  # Parses the sell amount from an expression like "bta*0.25" or "all"
  # DEPRECATED
  def parse_amount(expression)
    if expression.downcase == "all"
      #@variables[:bot].base_token_amount
      @variables[:bot].current_cycle.base_token_amount
    else
      eval(expression, binding_from_variables)
    end
  rescue Exception => e
    Rails.logger.error "Error parsing amount expression '#{expression}': #{e.message}"
    0
  end

  # Constructs a binding with only the strategy variables.
  def binding_from_variables
    b = binding
    allowed_keys = [:cpr, :ppr, :rhi, :vst, :vlt, :ssd, :pdi, :mom, :lsd, :ibp, :lbp, :bep, :scn, :bcn, :bta, :mam, :hip, :hlt, :lip, :llt, :lta, :lba, :lsp, :cap, :lps, :crt, :cma, :pcm, :plm, :lmc, :hma, :lma, :hmt, :lmt, :lmi, :tma, :lcp, :scp, :bpp, :ndp, :nd2]
    @variables.each do |key, value|
      b.local_variable_set(key.to_sym, value) if allowed_keys.include?(key.to_sym)
    end
    b
  end
end