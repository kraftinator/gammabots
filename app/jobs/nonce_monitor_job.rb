class NonceMonitorJob < ApplicationJob
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(wallet_id)
    wallet = Wallet.find_by(id: wallet_id)
    return unless wallet

    provider_url = ProviderUrlService.get_provider_url(wallet.chain.name)

    # Loop until there is no more nonce mismatch
    loop do
      data = check_nonce_mismatch(wallet.address, provider_url)

      unless data[:mismatch]
        cached = EthersService.cached_nonce(wallet.address)
        if cached != data[:latest]
          Rails.logger.warn("[NonceMonitorJob] Redis nonce (#{cached}) != on-chain latest (#{data[:latest]}), resetting.")
          EthersService.reset_nonce(wallet.address)
        end
        break
      end

      Rails.logger.info("[NonceMonitorJob] Clearing nonce #{data[:latest]} (pending: #{data[:pending]})")
      EthersService.clear_nonce(wallet, data[:latest], provider_url)

      sleep 1
    end
  end

  private

  def check_nonce_mismatch(address, provider_url)
    pending = EthersService.get_pending_nonce(address, provider_url)
    latest  = EthersService.get_latest_nonce(address, provider_url)
    {
      mismatch: pending != latest,
      pending:  pending,
      latest:   latest
    }
  end
end
