# lib/gammascript/expander.rb
module Gammascript
  module Expander
    SHORT_KEY_REGEX = /\b[a-z]{3}\b/

    def self.expand_condition(condition)
      return condition if condition.blank?

      condition.gsub(SHORT_KEY_REGEX) do |key|
        Gammascript::Constants::VALID_FIELDS[key] || key
      end
    end

    def self.expand_rules(rules_array)
      rules_array.map do |rule|
        rule.merge(
          "c" => expand_condition(rule["c"] || rule[:c])
        )
      end
    end
  end
end