class TokenApproval < ApplicationRecord
  belongs_to :wallet
  belongs_to :token

  before_validation :normalize_contract_address

  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }
  validates :wallet_id, :token_id, :status, :contract_address, presence: true
  validates :token_id, uniqueness: { scope: [:wallet_id, :contract_address] }

  def confirmed?
    status == "completed"
  end

  private

  def normalize_contract_address
    self.contract_address = contract_address.to_s.downcase if contract_address.present?
  end
end
