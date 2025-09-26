# app/jobs/fee_collections/fee_deposit_job.rb
module FeeCollections
  class FeeDepositJob < ApplicationJob
    RETRY_DELAY        = 30.seconds
    MAX_ATTEMPTS       = 10
    CONFIRMATION_DELAY = 5.seconds

    def perform(fee_collection_id, attempt = 1)
      fee = FeeCollection.find_by(id: fee_collection_id)
      return unless fee && fee.collection_pending? && fee.tx_hash.blank?

      bot          = fee.trade.bot
      bot_wallet   = bot.user.wallet_for_chain(bot.chain)
      router_wallet = Wallet.find_by!(kind: "router", chain: bot.chain)
      provider_url = bot.provider_url

      amount = fee.amount.to_d.round(18, BigDecimal::ROUND_DOWN)

      result = EthersService.send_ETH(
        bot_wallet,
        router_wallet.address,
        amount,
        provider_url
      )

      unless result["success"] && result["txHash"].present?
        if attempt < MAX_ATTEMPTS
          Rails.logger.warn "[FeeDepositJob] ETH send failed for FeeCollection##{fee.id}: #{result['error']}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(fee.id, attempt + 1)
        else
          Rails.logger.error "[FeeDepositJob] Giving up on FeeCollection##{fee.id} after #{MAX_ATTEMPTS} attempts"
          fee.update!(status: "failed")
        end
        return
      end

      tx_hash = result["txHash"]
      fee.update!(tx_hash: tx_hash, status: "pending") # pending until confirmed

      # Kick off confirm job
      FeeCollections::FeeDepositConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(fee.id)
    rescue => e
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[FeeDepositJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(fee_collection_id, attempt + 1)
      else
        Rails.logger.error "[FeeDepositJob] Fatal error for FeeCollection##{fee_collection_id}: #{e.class} #{e.message}"
        raise e # let Sidekiq dead-letter if unrecoverable
      end
    end
  end
end