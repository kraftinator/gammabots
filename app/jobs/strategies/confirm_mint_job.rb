module Strategies
  class ConfirmMintJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10

    # attempt param ensures we don’t retry forever
    def perform(strategy_id, attempt = 1)
      strategy = Strategy.find_by(id: strategy_id)
      return unless strategy
      return unless strategy.mint_status == "pending" && strategy.mint_tx_hash.present?

      provider_url = ProviderUrlService.get_provider_url(strategy.chain.name)
      tx_hash = strategy.mint_tx_hash
      receipt = EthersService.get_strategy_NFT_details(tx_hash, provider_url)

      if receipt.nil?
        if attempt < MAX_ATTEMPTS
          Rails.logger.info "[Strategies::ConfirmMintJob] Strategy##{strategy.id} mint still pending (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(strategy.id, attempt + 1)
        else
          Rails.logger.error "[Strategies::ConfirmMintJob] Giving up on Strategy##{strategy.id} mint after #{MAX_ATTEMPTS} attempts"
          strategy.update!(mint_status: "failed")
        end
        return
      end

      if receipt["status"].to_i == 1
        strategy_json = receipt["strategyJson"]
        validation_result = StrategiesValidate.call(strategy_json)
        status = validation_result[:valid] ? "active" : "inactive"

        strategy.update!(
          nft_token_id: receipt["tokenId"].to_s,
          strategy_json: strategy_json,
          owner_address: receipt["owner"],
          creator_address: receipt["owner"],
          contract_address: receipt["contractAddress"],
          mint_status: "confirmed",
          owner_refreshed_at: Time.current,
          status: status
        )
        Rails.logger.info "[Strategies::ConfirmMintJob] Mint confirmed for Strategy##{strategy.id} (token #{receipt["tokenId"]}, tx: #{tx_hash})"
      else
        Rails.logger.error "[Strategies::ConfirmMintJob] Mint tx reverted for Strategy##{strategy.id} (tx: #{tx_hash})"
        strategy.update!(mint_status: "failed")
      end
    end

  end
end