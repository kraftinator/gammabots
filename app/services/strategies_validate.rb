# frozen_string_literal: true

require "dentaku"
require "gammascript/constants"

# ==============================================================
#  Gammabots :: StrategiesValidate
#
#  Validates a Gammascript strategy JSON for syntax, variables, and actions.
#  - Ensures JSON is valid and an array of rules
#  - Confirms all condition variables exist in VALID_FIELDS
#  - Confirms all actions are valid and case-sensitive
#  - Uses Dentaku to validate condition syntax and operators
#  - Returns a compressed JSON form (with short field names)
# ==============================================================

class StrategiesValidate
  include Gammascript::Constants

  VALID_ACTIONS = [
    "buy",
    "sell all",
    "deact",
    "reset",
    "skip",
    "liquidate"
  ].freeze

  def self.call(strategy_json)
    new(strategy_json).call
  end

  def initialize(strategy_json)
    @strategy_json = strategy_json
    @calc = Dentaku::Calculator.new

    # Register valid variables (mock values so Dentaku can parse)
    (VALID_FIELDS.keys + VALID_FIELDS.values).uniq.each do |field|
      @calc.store(field.to_sym => 0)
    end
  end

  def call
    begin
      rules = JSON.parse(@strategy_json)
      unless rules.is_a?(Array)
        return { valid: false, errors: ["Strategy must be an array of rule objects"] }
      end

      errors = []

      rules.each_with_index do |rule, i|
        # --- Key presence checks ---
        unless rule.key?("c") || rule.key?("conditions")
          errors << "Rule #{i + 1} missing 'c' (conditions)"
          next
        end
        unless rule.key?("a") || rule.key?("actions")
          errors << "Rule #{i + 1} missing 'a' (actions)"
          next
        end

        condition_str = rule["c"] || rule["conditions"]
        action_arr    = rule["a"] || rule["actions"]

        # --- Normalize logical operators for Dentaku ---
        normalized = condition_str
          .gsub("&&", " and ")
          .gsub("||", " or ")
          .gsub("!", " not ")

        # --- Validate condition tokens (field existence) ---
        tokens = normalized.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
        tokens.each do |token|
          next if %w[and or not true false].include?(token)
          unless VALID_FIELDS.key?(token)
            case_match = VALID_FIELDS.keys.find { |f| f.downcase == token.downcase }
            if case_match && case_match != token
              errors << "Unknown variable '#{token}' (did you mean '#{case_match}'?)"
            else
              errors << "Unknown variable '#{token}'"
            end
          end
        end

        # --- Validate operator syntax using Dentaku ---
        begin
          @calc.evaluate!(normalized)
        rescue Dentaku::ParseError, Dentaku::UnboundVariableError => e
          errors << "Rule #{i + 1} invalid expression: #{e.message}"
        end

        # --- Validate actions ---
        unless action_arr.is_a?(Array)
          errors << "Rule #{i + 1} actions must be an array"
          next
        end

        action_arr.each do |action|
          if action.start_with?("sell ")
            arg = action.split("sell ", 2).last.strip.downcase

            if arg == "all"
              next
            elsif arg.match?(/\A\d*\.?\d+\z/)
              fraction = arg.to_f
              if fraction <= 0 || fraction > 1
                errors << "Rule #{i + 1} invalid sell fraction '#{arg}' (must be >0 and ≤1)"
              end
            else
              errors << "Rule #{i + 1} invalid sell syntax '#{action}'"
            end

            next
          end

          unless VALID_ACTIONS.include?(action)
            case_match = VALID_ACTIONS.find { |a| a.downcase == action.downcase }
            if case_match && case_match != action
              errors << "Unknown action '#{action}' (did you mean '#{case_match}'?)"
            else
              errors << "Unknown action '#{action}'"
            end
          end
        end
      end

      return { valid: false, errors: errors } if errors.any?

      # --- Produce compressed form ---
      compressed = JSON.generate(
        rules.map { |r| compress_rule(r) },
        escape_html: false
      )

      if Strategy.exists?(strategy_json: compressed)
        return { valid: false, errors: ["Duplicate strategy JSON already exists"] }
      end

      { valid: true, compressed: compressed }

    rescue JSON::ParserError
      { valid: false, errors: ["Invalid JSON"] }
    end
  end

  private

  def compress_rule(rule)
    {
      "c" => convert_conditions(rule["c"] || rule["conditions"]),
      "a" => (rule["a"] || rule["actions"]).map(&:strip)
    }
  end

  def convert_conditions(condition_str)
    out = condition_str.dup

    # Replace human-readable field names with compact Gammascript codes
    VALID_FIELDS.each do |key, short|
      out.gsub!(/\b#{key}\b/, short)
    end

    # Remove all unnecessary whitespace
    out.gsub!(/\s+/, "")
    out
  end
end