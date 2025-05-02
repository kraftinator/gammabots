class TokenApproval < ApplicationRecord
  belongs_to :wallet
  belongs_to :token

  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }
  validates :wallet_id, :token_id, :status, presence: true
  validates :token_id, uniqueness: { scope: :wallet_id }

  def confirmed?
    status == "completed"
  end
end
