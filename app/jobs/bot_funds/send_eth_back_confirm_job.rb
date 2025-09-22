module BotFunds
  class SendEthBackConfirmJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10

    def perform(bot_id, attempt = 1)
      bot = Bot.find_by(id: bot_id)
      return unless bot
      return unless bot.funds_return_status == "pending"

      tx_hash = bot.funds_return_tx_hash
      return unless tx_hash.present?

      provider_url = bot.provider_url
      receipt      = EthersService.get_ETH_transfer_details(tx_hash, provider_url)

      if receipt.nil? || receipt["status"].nil?
        if attempt < MAX_ATTEMPTS
          Rails.logger.info "[BotFunds::SendEthBackConfirmJob] Bot##{bot.id} send still pending (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(bot.id, tx_hash, attempt + 1)
        else
          Rails.logger.error "[BotFunds::SendEthBackConfirmJob] Giving up on Bot##{bot.id} send after #{MAX_ATTEMPTS} attempts"
          bot.update!(funds_return_status: "failed")
        end
        return
      end

      if receipt["status"].to_i == 1
        Rails.logger.info "[BotFunds::SendEthBackConfirmJob] ETH return confirmed for Bot##{bot.id} (tx: #{tx_hash})"
        bot.update!(
          funds_return_status: "returned",
          funds_returned_at: Time.current
        )
      else
        Rails.logger.error "[BotFunds::SendEthBackConfirmJob] ETH return tx reverted for Bot##{bot.id} (tx: #{tx_hash})"
        bot.update!(funds_return_status: "failed")
      end
    end
  end
end