FactoryBot.define do
  factory :bot do
    association :user
    association :chain
    association :token_pair
    initial_buy_price { 1.0 }
    base_token_amount { 100 }
    quote_token_amount { 0 }
    active { true }
  end
end
