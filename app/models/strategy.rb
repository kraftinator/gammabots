class Strategy < ApplicationRecord
  belongs_to :chain
  has_many :bots

  validates :contract_address, :nft_token_id, :strategy_json, presence: true
  validates :contract_address, uniqueness: { scope: :nft_token_id, message: "should be unique for a given NFT" }
  validates :strategy_json, presence: true, uniqueness: true
  validate  :strategy_json_must_be_valid_json

  private

  def strategy_json_must_be_valid_json
    JSON.parse(strategy_json)
  rescue JSON::ParserError
    errors.add(:strategy_json, "must be valid JSON")
  end
end
