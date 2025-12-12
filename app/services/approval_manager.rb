class ApprovalManager
  UNISWAP_V3_ROUTER = "0x2626664c2603336e57b271c5c0b26f421741e481"
  ZERO_EX_SPENDER = "0x0000000000001ff3684f28c67538d4d072c22734"
  CONFIRMATION_DELAY = 5.seconds

  # Idempotently ensure infinite allowance
  def self.ensure_infinite!(wallet:, token:, provider_url:, spender_address: ZERO_EX_SPENDER)
=begin    
    record = TokenApproval.find_or_initialize_by(wallet: wallet, token: token, contract_address: spender_address)

    return if record.confirmed?

    # If there's already a pending tx, don't keep re-enqueuing confirmers
    if record.status == "pending" && record.tx_hash.present?
      ConfirmApprovalJob.set(wait: CONFIRMATION_DELAY).perform_later(record.id)
      return
    end

    if record.new_record? || record.status == 'failed' || record.tx_hash.blank?
      result = EthersService.infinite_approve(wallet, token.contract_address, spender_address, provider_url)
      record.assign_attributes(tx_hash: result["txHash"], status: 'pending')
      record.save!
    end

    # schedule the confirmer
    ConfirmApprovalJob.set(wait: CONFIRMATION_DELAY).perform_later(record.id)
=end

    record = TokenApproval.find_or_initialize_by(
      wallet: wallet,
      token: token,
      contract_address: spender_address
    )

    return if record.confirmed?

    # If there's already a pending tx, don't keep re-enqueuing confirmers
    if record.status == "pending" && record.tx_hash.present?
      ConfirmApprovalJob.set(wait: CONFIRMATION_DELAY).perform_later(record.id)
      return
    end

    # Only (re)submit if new or failed
    if record.new_record? || record.status == "failed" || record.tx_hash.blank?
      result = EthersService.infinite_approve(wallet, token.contract_address, spender_address, provider_url)

      tx_hash = result["txHash"].presence

      if tx_hash.nil?
        record.update!(status: "failed", tx_hash: nil) # ideally also store result/error
        return
      end

      record.update!(status: "pending", tx_hash: tx_hash)
    end

    ConfirmApprovalJob.set(wait: CONFIRMATION_DELAY).perform_later(record.id)

  end

end
