class TradingStrategyInterpreter
  BOUNDARY_STEPS_MAX = 10

  def initialize(strategy_json, variables, sim=false)
    @sim = sim
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
        result = TradeExecutionService.buy(@variables.merge({ step: step })) if !@sim
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
        current_cpr = @variables[:cpr].to_f

        if condition_includes_cpr?(rule['c'])
          boundary = boundary_cpr_down(rule['c'], current_cpr, step: 0.01, cap_steps: BOUNDARY_STEPS_MAX)
          min_amount_out = sell_amount * boundary
        else
          min_amount_out = 0
        end
        
        if !@sim
          result = TradeExecutionService.sell(@variables.merge({ step: step }), sell_amount, min_amount_out)
        else
          puts "current_cpr    = #{current_cpr.to_d.to_s}"
          puts "boundary       = #{boundary.to_d.to_s}"
          puts "min_amount_out = #{min_amount_out.to_s}"
        end
        swap_executed = true if result.present?
      when /\Aliquidate\z/i
        if !@sim
          result = TradeExecutionService.sell(@variables.merge({ step: step }), @variables[:bot].current_cycle.base_token_amount, 0)
        end
        swap_executed = true if result.present?
      when /\Adeact\s+force\z/i
        # 'deact force' is a legacy action
        @variables[:bot].forced_deactivate
        Rails.logger.info "Bot #{@variables[:bot].id}: Forced deactivated."
      when /\Adeact\z/i
        has_bought = (@variables[:bcn] || 0).to_i > 0
        if has_bought
          if swap_executed
            #@variables[:bot].deactivate
            @variables[:bot].request_deactivation
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

  # Re-evaluate the SAME condition with a temporarily adjusted cpr.
  def condition_holds_with_cpr?(condition_str, cpr_val)
    original = @variables[:cpr]
    @variables[:cpr] = cpr_val
    begin
      eval(condition_str, binding_from_variables)
    rescue => e
      Rails.logger.error "Bot #{@variables[:bot].id}: Error in condition_holds_with_cpr?: #{e.message}"
      false
    ensure
      @variables[:cpr] = original
    end
  end

  # Step cpr DOWN (only) by 1% per step, up to 5% total, keeping the rule true.
  # Returns the lowest cpr that still satisfies the condition (or start_cpr if no lower cpr works).
  def boundary_cpr_down(condition_str, start_cpr, step: 0.01, cap_steps: BOUNDARY_STEPS_MAX)
    # Skip entirely if condition doesn’t involve cpr
    #return start_cpr unless condition_str.to_s.match?(/\bcpr\b/)
    return start_cpr unless condition_includes_cpr?(condition_str)
    return start_cpr unless start_cpr.is_a?(Numeric) && start_cpr.positive?

    best = start_cpr
    1.upto(cap_steps) do |i|
      candidate = start_cpr * (1.0 - step * i)
      break if candidate <= 0.0

      if condition_holds_with_cpr?(condition_str, candidate)
        best = candidate
      else
        break # as soon as rule fails, stop stepping lower
      end
    end

    best
  end

  # Does the condition string mention cpr?
  def condition_includes_cpr?(condition_str)
    !!(/\bcpr\b/.match(condition_str.to_s))
  end

  # Constructs a binding with only the strategy variables.
  def binding_from_variables
    b = binding
    allowed_keys = [:cpr, :ppr, :rhi, :vst, :vlt, :ssd, :pdi, :mom, :lsd, :ibp, :lbp, :bep, :scn, :bcn, :bta, :mam, :hip, :hlt, :lip, :llt, :lta, :lba, :lsp, :cap, :hps, :lps, :crt, :cma, :pcm, :plm, :lmc, :hma, :lma, :hmt, :lmt, :lmi, :tma, :lcp, :scp, :bpp, :ndp, :nd2]
    @variables.each do |key, value|
      b.local_variable_set(key.to_sym, value) if allowed_keys.include?(key.to_sym)
    end
    b
  end
end