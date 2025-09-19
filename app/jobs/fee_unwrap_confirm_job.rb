# app/jobs/fee_unwrap_confirm_job.rb
class FeeUnwrapConfirmJob < ApplicationJob
  RETRY_DELAY  = 30.seconds
  MAX_ATTEMPTS = 10

  def perform(fee_collection_id, attempt = 1)
    fee = FeeCollection.find_by(id: fee_collection_id)
    return unless fee && fee.unwrap_pending? && fee.unwrap_tx_hash.present?

    provider_url = fee.trade.bot.provider_url
    receipt      = EthersService.get_transfer_receipt(fee.unwrap_tx_hash, provider_url)

    if receipt.nil?
      if attempt < MAX_ATTEMPTS
        Rails.logger.info "[FeeUnwrapConfirmJob] FeeCollection##{fee.id} unwrap still pending (attempt #{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(fee.id, attempt + 1)
      else
        Rails.logger.error "[FeeUnwrapConfirmJob] Giving up on FeeCollection##{fee.id} unwrap after #{MAX_ATTEMPTS} attempts"
        fee.update!(unwrap_status: "failed")
      end
      return
    end

    if receipt["status"].to_i == 1
      fee.update!(unwrap_status: "unwrapped", unwrapped_at: Time.current)
      Rails.logger.info "[FeeUnwrapConfirmJob] Fee unwrapped for FeeCollection##{fee.id} (tx: #{fee.unwrap_tx_hash})"
    else
      fee.update!(unwrap_status: "failed")
      Rails.logger.error "[FeeUnwrapConfirmJob] Unwrap tx reverted for FeeCollection##{fee.id} (tx: #{fee.unwrap_tx_hash})"
    end
  rescue => e
    if attempt < MAX_ATTEMPTS
      Rails.logger.warn "[FeeUnwrapConfirmJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
      self.class.set(wait: RETRY_DELAY).perform_later(fee_collection_id, attempt + 1)
    else
      Rails.logger.error "[FeeUnwrapConfirmJob] Fatal error for FeeCollection##{fee_collection_id}: #{e.class} #{e.message}"
      raise e
    end
  end
end