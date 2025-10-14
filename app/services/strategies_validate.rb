# app/services/strategies_validate.rb
# frozen_string_literal: true

require "gammascript/constants"

# ==============================================================
#  Gammabots :: StrategiesValidate
#
#  Validates a Gammascript strategy JSON for syntax, variables, and actions.
#  - Ensures the JSON is valid and is an array of rules
#  - Confirms all condition variables exist in VALID_FIELDS
#  - Confirms all actions are valid and case-sensitive
#  - Returns a compressed JSON form (with short field names)
# ==============================================================

class StrategiesValidate
  include Gammascript::Constants

  VALID_ACTIONS = [
    "buy init",
    "sell all",
    "deact",
    "reset"
  ].freeze

  def self.call(strategy_json)
    new(strategy_json).call
  end

  def initialize(strategy_json)
    @strategy_json = strategy_json
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

        # --- Validate condition tokens ---
        tokens = condition_str.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
        tokens.each do |token|
          next if %w[and or true false].include?(token)
          unless VALID_FIELDS.key?(token)
            case_match = VALID_FIELDS.keys.find { |f| f.downcase == token.downcase }
            if case_match && case_match != token
              errors << "Unknown variable '#{token}' (did you mean '#{case_match}'?)"
            else
              errors << "Unknown variable '#{token}'"
            end
          end
        end

        # --- Validate actions ---
        unless action_arr.is_a?(Array)
          errors << "Rule #{i + 1} actions must be an array"
          next
        end

        action_arr.each do |action|
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

      { valid: true, compressed: compressed }

    rescue JSON::ParserError
      { valid: false, errors: ["Invalid JSON"] }
    end
  end

  private

  def compress_rule(rule)
    {
      "c" => convert_conditions(rule["c"] || rule["conditions"]),
      "a" => rule["a"] || rule["actions"]
    }
  end

  def convert_conditions(condition_str)
    out = condition_str.dup
    VALID_FIELDS.each do |key, short|
      out.gsub!(/\b#{key}\b/, short)
    end
    out
  end
end