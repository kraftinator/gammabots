class ApprovalManager
  UNISWAP_V3_ROUTER = "0x2626664c2603336e57b271c5c0b26f421741e481"
  ZERO_EX_SPENDER = "0x0000000000001ff3684f28c67538d4d072c22734"
  CONFIRMATION_DELAY = 5.seconds

  # Idempotently ensure infinite allowance
  def self.ensure_infinite!(wallet:, token:, provider_url:, spender_address: ZERO_EX_SPENDER)
    record = TokenApproval.find_or_initialize_by(wallet: wallet, token: token, contract_address: spender_address)

    return if record.confirmed?

    if record.new_record? || record.status == 'failed'
      result = EthersService.infinite_approve(wallet, token.contract_address, spender_address, provider_url)
      record.assign_attributes(tx_hash: result["txHash"], status: 'pending')
      record.save!
    end

    # schedule the confirmer
    ConfirmApprovalJob.set(wait: CONFIRMATION_DELAY).perform_later(record.id)
  end
end
