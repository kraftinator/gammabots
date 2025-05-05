class TokenPairPrice < ApplicationRecord
  # Associations
  belongs_to :token_pair

  # Validations
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :token_pair, presence: true

  # Scopes
  scope :latest_first, -> { order(created_at: :desc) }
  scope :for_token_pair, ->(token_pair_id) { where(token_pair_id: token_pair_id) }

  # Callbacks
  after_create :remove_old_prices

  private

  def remove_old_prices
    # Keep only the 100 most recent records for this token_pair
    excess_count = token_pair.token_pair_prices.count - 720
    if excess_count > 0
      token_pair.token_pair_prices
                .order(created_at: :asc) # Oldest first
                .limit(excess_count)     # Number to delete
                .destroy_all             # Delete the oldest
    end
  end
end