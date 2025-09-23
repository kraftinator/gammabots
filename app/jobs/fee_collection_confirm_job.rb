# app/jobs/fee_collection_confirm_job.rb
class FeeCollectionConfirmJob < ApplicationJob
  RETRY_DELAY  = 30.seconds
  MAX_ATTEMPTS = 10

  def perform(fee_collection_id, attempt = 1)
    fee = FeeCollection.find_by(id: fee_collection_id)
    return unless fee && fee.tx_hash.present? && fee.collection_pending?

    #provider_url = ProviderUrlService.get_provider_url(fee.trade.bot.chain.name)
    bot = fee.trade.bot
    provider_url = bot.provider_url
    receipt      = EthersService.get_transfer_receipt(fee.tx_hash, provider_url)

    if receipt.nil?
      if attempt < MAX_ATTEMPTS
        Rails.logger.info "[FeeCollectionConfirmJob] FeeCollection##{fee.id} still pending (attempt #{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(fee.id, attempt + 1)
      else
        Rails.logger.error "[FeeCollectionConfirmJob] Giving up on FeeCollection##{fee.id} after #{MAX_ATTEMPTS} attempts"
        fee.update!(status: "failed")
      end
      return
    end

    if receipt["status"].to_i == 1
      fee.update!(status: "collected", collected_at: Time.current)
      Rails.logger.info "[FeeCollectionConfirmJob] Fee collected for FeeCollection##{fee.id} (tx: #{fee.tx_hash})"
      FeeUnwrapJob.perform_later(fee.id)
    else
      fee.update!(status: "failed")
      Rails.logger.error "[FeeCollectionConfirmJob] Fee collection tx reverted for FeeCollection##{fee.id} (tx: #{fee.tx_hash})"
    end
  rescue => e
    if attempt < MAX_ATTEMPTS
      Rails.logger.warn "[FeeCollectionConfirmJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
      self.class.set(wait: RETRY_DELAY).perform_later(fee_collection_id, attempt + 1)
    else
      Rails.logger.error "[FeeCollectionConfirmJob] Fatal error for FeeCollection##{fee_collection_id}: #{e.class} #{e.message}"
      raise e # optional: re-raise so Sidekiq dead-letters it
    end
  end
end