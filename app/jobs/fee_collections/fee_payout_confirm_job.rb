# app/jobs/fee_collections/fee_payout_confirm_job.rb
module FeeCollections
  class FeePayoutConfirmJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10

    def perform(fee_recipient_id, attempt = 1)
      recipient = FeeRecipient.find_by(id: fee_recipient_id)
      return unless recipient
      return unless recipient.status_submitted?

      tx_hash = recipient.tx_hash
      return unless tx_hash.present?

      bot          = recipient.fee_collection.trade.bot
      provider_url = bot.provider_url
      receipt      = EthersService.get_ETH_transfer_details(tx_hash, provider_url)

      if receipt.nil? || receipt["status"].nil?
        if attempt < MAX_ATTEMPTS
          Rails.logger.info "[FeePayoutConfirmJob] FeeRecipient##{recipient.id} send still pending (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(recipient.id, attempt + 1)
        else
          Rails.logger.error "[FeePayoutConfirmJob] Giving up on FeeRecipient##{recipient.id} after #{MAX_ATTEMPTS} attempts"
          recipient.update!(status: :failed)
        end
        return
      end

      if receipt["status"].to_i == 1
        Rails.logger.info "[FeePayoutConfirmJob] ETH payout confirmed for FeeRecipient##{recipient.id} (tx: #{tx_hash})"
        recipient.update!(
          status: :confirmed,
          confirmed_at: Time.current
        )
      else
        Rails.logger.error "[FeePayoutConfirmJob] ETH payout tx reverted for FeeRecipient##{recipient.id} (tx: #{tx_hash})"
        recipient.update!(status: :failed)
      end
    end
  end
end