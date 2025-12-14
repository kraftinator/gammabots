class Strategy < ApplicationRecord
  belongs_to :chain
  has_many :bots

  #validates :contract_address, :nft_token_id, :strategy_json, presence: true
  #validates :contract_address, uniqueness: { scope: :nft_token_id, message: "should be unique for a given NFT" }
  #validates :strategy_json, presence: true, uniqueness: true
  validates :contract_address,
    uniqueness: {
      scope: :nft_token_id,
      message: "should be unique for a given NFT"
    },
    unless: -> { nft_token_id.nil? }
  validate  :strategy_json_must_be_valid_json
  validates :owner_address, allow_nil: true, format: { with: /\A0x[a-fA-F0-9]{40}\z/, message: "must be a valid Ethereum address" }
  validates :creator_address, allow_nil: true, format: { with: /\A0x[a-fA-F0-9]{40}\z/, message: "must be a valid Ethereum address" }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }

  def current_owner_address
    owner_address
  end

  def creator
    # 1. Prefer user identity (canonical)
    user = User.active.find_by(created_by_wallet: creator_address)
    return user if user

    # 2. Fallback: find a bot funded by this wallet, then its user
    bot = Bot.find_by(funder_address: creator_address)
    return bot.user if bot

    nil
  end

  def active?
    status == 'active'
  end

  def longform
    Gammascript::Expander.expand_rules(JSON.parse(strategy_json))
  end

  private

  def strategy_json_must_be_valid_json
    return if strategy_json.blank? 
    
    JSON.parse(strategy_json)
  rescue JSON::ParserError
    errors.add(:strategy_json, "must be valid JSON")
  end
end
