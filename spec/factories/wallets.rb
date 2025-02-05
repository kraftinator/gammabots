FactoryBot.define do
  factory :wallet do
    user
    chain
    private_key { SecureRandom.hex(32) }
  end
end
