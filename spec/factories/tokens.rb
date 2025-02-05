FactoryBot.define do
  factory :token do
    sequence(:name) { |n| "Token#{n}" }
    sequence(:symbol) { |n| "TKN#{n}" }
    decimals { 18 }
    #contract_address { Faker::Blockchain::Ethereum.address }
    sequence(:contract_address) { |n| "123456abcdef#{n}" }
    association :chain
  end
end
