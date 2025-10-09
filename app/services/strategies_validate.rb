# app/services/strategies_validate.rb
class StrategiesValidate
  def self.call(strategy_json)
    new(strategy_json).call
  end

  def initialize(strategy_json)
    @strategy_json = strategy_json
  end

  def call
    begin
      rules = JSON.parse(@strategy_json) # just ensure it's valid JSON
      compressed = JSON.generate(rules, escape_html: false) # keep > < & as-is
      {
        valid: true,
        compressed: compressed
      }
    rescue JSON::ParserError
      {
        valid: false,
        errors: ["Invalid JSON"]
      }
    end
  end
end