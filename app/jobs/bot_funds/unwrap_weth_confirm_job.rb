# app/jobs/bot_funds/unwrap_weth_confirm_job.rb
module BotFunds
  class UnwrapWethConfirmJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10

    def perform(bot_id, attempt = 1)
      bot = Bot.find_by(id: bot_id)
      return unless bot
      return unless bot.weth_unwrap_status == "pending" && bot.weth_unwrap_tx_hash.present?

      provider_url = bot.provider_url
      receipt      = EthersService.get_wrap_receipt(bot.weth_unwrap_tx_hash, provider_url)

      if receipt.nil?
        if attempt < MAX_ATTEMPTS
          Rails.logger.info "[BotFunds::UnwrapWethConfirmJob] Bot##{bot.id} unwrap still pending (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(bot.id, attempt + 1)
        else
          Rails.logger.error "[BotFunds::UnwrapWethConfirmJob] Giving up on Bot##{bot.id} unwrap after #{MAX_ATTEMPTS} attempts"
          bot.update!(weth_unwrap_status: "failed")
        end
        return
      end

      if receipt["status"].to_i == 1
        bot.update!(
          weth_unwrap_status: "unwrapped",
          weth_unwrapped_at:  Time.current
        )
        Rails.logger.info "[BotFunds::UnwrapWethConfirmJob] unwrap confirmed for Bot##{bot.id} (tx: #{bot.weth_unwrap_tx_hash})"

        # Kick off sending ETH back
        BotFunds::SendEthBackJob.perform_later(bot.id)
      else
        Rails.logger.error "[BotFunds::UnwrapWethConfirmJob] unwrap tx reverted for Bot##{bot.id} (tx: #{bot.weth_unwrap_tx_hash})"
        bot.update!(weth_unwrap_status: "failed")
      end
    end
  end
end 