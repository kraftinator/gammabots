class ConfirmApprovalJob < ApplicationJob
  RETRY_DELAY = 30.seconds
  MAX_TRIES   = 10

  def perform(approval_id, attempts = 1)
    approval = TokenApproval.find_by(id: approval_id)
    return unless approval&.status == 'pending'

    wallet       = approval.wallet
    token_addr   = approval.token.contract_address
    provider_url = ProviderUrlService.get_provider_url(wallet.chain.name)

    if EthersService.is_infinite_approval(wallet.private_key, token_addr, provider_url)
      approval.update!(status: 'completed', confirmed_at: Time.current)
    elsif attempts < MAX_TRIES
      self.class
          .set(wait: RETRY_DELAY)
          .perform_later(approval.id, attempts + 1)
    else
      approval.update!(status: 'failed')
      Rails.logger.warn "[ConfirmApprovalJob] Giving up after #{MAX_TRIES} tries for Approval##{approval.id}"
    end
  end
end
