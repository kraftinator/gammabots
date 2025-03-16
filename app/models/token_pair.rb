class TokenPair < ApplicationRecord
  belongs_to :chain
  belongs_to :base_token, class_name: "Token"
  belongs_to :quote_token, class_name: "Token"
  has_many :bots, dependent: :destroy
  has_many :token_pair_prices, dependent: :destroy

  validates :base_token, presence: true
  validates :quote_token, presence: true
  validates :chain, presence: true
  validate :tokens_cannot_be_same

  # Validation
  def tokens_cannot_be_same
    if base_token_id == quote_token_id
      errors.add(:quote_token, "cannot be the same as base token")
    end
  end

  def name
    "#{base_token.symbol}/#{quote_token.symbol}"
  end

  def latest_price
    update_price if price_stale?
    current_price
  end

  private

  def price_stale?
    price_updated_at.nil? || price_updated_at < 1.minute.ago
  end

  def update_price
    TokenPriceService.update_price_for_pair(self)
  end
end
