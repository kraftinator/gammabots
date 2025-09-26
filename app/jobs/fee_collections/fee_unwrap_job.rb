# app/jobs/fee_collections/fee_unwrap_job.rb
module FeeCollections
  class FeeUnwrapJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10
    CONFIRMATION_DELAY = 5.seconds

    def perform(fee_collection_id, attempt = 1)
      fee = FeeCollection.find_by(id: fee_collection_id)
      return unless fee && fee.unwrap_status == "pending" && fee.unwrap_tx_hash.blank?

      bot = fee.trade.bot
      #router_wallet = Wallet.find_by!(kind: "router", chain: bot.chain)
      bot_wallet = bot.user.wallet_for_chain(bot.chain)
      provider_url  = bot.provider_url

      unwrap_amount = fee.amount.to_d.round(18, BigDecimal::ROUND_DOWN)

      result = EthersService.convert_WETH_to_ETH(
        bot_wallet,
        provider_url,
        unwrap_amount
      )

      unless result["success"] && result["txHash"].present?
        if attempt < MAX_ATTEMPTS
          Rails.logger.warn "[FeeUnwrapJob] unwrap failed for FeeCollection##{fee.id}: #{result["error"]}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(fee.id, attempt + 1)
        else
          Rails.logger.error "[FeeUnwrapJob] Giving up on FeeCollection##{fee.id} after #{MAX_ATTEMPTS} attempts"
          fee.update!(unwrap_status: "failed")
        end
        return
      end

      fee.update!(unwrap_tx_hash: result["txHash"], unwrap_status: "submitted")

      # Kick off confirm job
      FeeUnwrapConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(fee.id)
    rescue => e
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[FeeUnwrapJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(fee_collection_id, attempt + 1)
      else
        Rails.logger.error "[FeeUnwrapJob] Fatal error for FeeCollection##{fee_collection_id}: #{e.class} #{e.message}"
        raise e
      end
    end
  end
end