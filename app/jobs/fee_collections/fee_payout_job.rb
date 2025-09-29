# app/jobs/fee_collections/fee_payout_job.rb
module FeeCollections
  class FeePayoutJob < ApplicationJob
    RETRY_DELAY        = 30.seconds
    MAX_ATTEMPTS       = 10
    CONFIRMATION_DELAY = 5.seconds

    def perform(fee_recipient_id, attempt = 1)
      recipient = FeeRecipient.find_by(id: fee_recipient_id)
      return unless recipient
      return if recipient.status_submitted? || recipient.status_confirmed?

      send_amount = recipient.eth_amount
      return if send_amount <= 0

      fee          = recipient.fee_collection
      bot          = fee.trade.bot
      router_wallet = Wallet.find_by!(kind: "router", chain: bot.chain)
      provider_url  = bot.provider_url
      to_address    = recipient.recipient_address

      if to_address.blank?
        Rails.logger.error "[FeePayoutJob] FeeRecipient##{recipient.id} has no recipient_address"
        recipient.update!(status: :failed)
        return
      end

      result = EthersService.send_ETH(
        router_wallet,
        to_address,
        send_amount,
        provider_url
      )

      unless result["success"] && result["txHash"].present?
        if attempt < MAX_ATTEMPTS
          Rails.logger.warn "[FeePayoutJob] send ETH failed for FeeRecipient##{recipient.id}: #{result["error"]}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(recipient.id, attempt + 1)
        else
          Rails.logger.error "[FeePayoutJob] Giving up for FeeRecipient##{recipient.id} after #{MAX_ATTEMPTS} attempts"
          recipient.update!(status: :failed)
        end
        return
      end

      tx_hash = result["txHash"]
      Rails.logger.info "[FeePayoutJob] submitted send ETH tx for FeeRecipient##{recipient.id} (tx: #{tx_hash})"

      recipient.update!(
        status: :submitted,
        tx_hash: tx_hash
      )

      FeeCollections::FeePayoutConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(recipient.id)
    rescue => e
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[FeePayoutJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(fee_recipient_id, attempt + 1)
      else
        Rails.logger.error "[FeePayoutJob] Fatal error for FeeRecipient##{fee_recipient_id}: #{e.class} #{e.message}"
        recipient&.update!(status: :failed)
        raise e
      end
    end
  end
end