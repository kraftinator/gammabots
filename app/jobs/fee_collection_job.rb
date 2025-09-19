# app/jobs/fee_collection_job.rb
class FeeCollectionJob < ApplicationJob
  RETRY_DELAY = 30.seconds
  MAX_TRIES   = 10
  CONFIRMATION_DELAY = 5.seconds

  def perform(fee_collection_id, attempts = 1)
    fee = FeeCollection.find_by(id: fee_collection_id)
    return unless fee && fee.status == "pending" && fee.tx_hash.blank?

    trade        = fee.trade
    bot          = trade.bot
    token        = Token.find_by!(chain: bot.chain, symbol: "WETH")
    router_wallet = Wallet.find_by!(kind: "router", chain: bot.chain)
    provider_url = bot.provider_url

    result = EthersService.send_erc20(
      bot.user.wallet_for_chain(bot.chain),
      token.contract_address,
      router_wallet.address,
      fee.amount * 0.9999999999,
      token.decimals,
      provider_url
    )

    unless result["success"] && result["txHash"].present?
      if attempts < MAX_TRIES
        Rails.logger.warn "[FeeCollectionJob] send_erc20 failed for FeeCollection##{fee.id}: #{result["error"]}; retrying (#{attempts}/#{MAX_TRIES})"
        self.class.set(wait: RETRY_DELAY).perform_later(fee.id, attempts + 1)
      else
        Rails.logger.error "[FeeCollectionJob] Giving up on FeeCollection##{fee.id} after #{MAX_TRIES} attempts"
        fee.update!(status: "failed")
      end
      return
    end

    tx_hash = result["txHash"]
    fee.update!(tx_hash: tx_hash, status: "pending") # status still pending until confirmed

    # Kick off confirm job to wait for mining before marking as collected
    FeeCollectionConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(fee.id)
  rescue => e
    if attempts < MAX_TRIES
      Rails.logger.warn "[FeeCollectionJob] #{e.class}: #{e.message}; retrying (#{attempts}/#{MAX_TRIES})"
      self.class.set(wait: RETRY_DELAY).perform_later(fee_collection_id, attempts + 1)
    else
      Rails.logger.error "[FeeCollectionJob] Fatal error for FeeCollection##{fee_collection_id}: #{e.class} #{e.message}"
      raise e # re-raise so it can be dead-lettered if needed
    end
  end
end