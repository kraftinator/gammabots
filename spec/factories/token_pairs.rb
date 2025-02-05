FactoryBot.define do
  factory :token_pair do
    association :chain
    base_token { association :token, symbol: "DEGEN" }
    quote_token { association :token, symbol: "WETH" }
  end
end
