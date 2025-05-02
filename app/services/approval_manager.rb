class ApprovalManager
  CONFIRMATION_DELAY = 5.seconds

  # Idempotently ensure infinite allowance
  def self.ensure_infinite!(wallet:, token:, provider_url:)
    record = TokenApproval.find_or_initialize_by(wallet: wallet, token: token)

    return if record.confirmed?

    if record.new_record? || record.status == 'failed'
      result = EthersService.infinite_approve(wallet, token.contract_address, provider_url)
      record.assign_attributes(tx_hash: result["txHash"], status: 'pending')
      record.save!
    end

    # schedule the confirmer
    ConfirmApprovalJob.set(wait: CONFIRMATION_DELAY).perform_later(record.id)
  end
end
