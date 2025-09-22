module BotFunds
  class SendEthBackJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10
    CONFIRMATION_DELAY = 5.seconds

    def perform(bot_id, attempt = 1)
      bot = Bot.find_by(id: bot_id)
      return unless bot
      return unless bot.weth_unwrap_status == "unwrapped"
      return if bot.funds_return_status == "returned" || bot.funds_return_status == "pending"

      cycle        = bot.current_cycle
      #send_amount  = cycle.quote_token_amount.to_d.round(18, BigDecimal::ROUND_DOWN)
      send_amount = bot.weth_unwrapped_amount.to_d.round(18, BigDecimal::ROUND_DOWN)
      return if send_amount <= 0

      bot_wallet   = bot.user.wallet_for_chain(bot.chain)
      provider_url = bot.provider_url
      to_address   = bot.funder_address
      if to_address.blank?
        Rails.logger.error "[BotFunds::SendEthBackJob] Bot##{bot.id} has no funder_address, cannot return funds"
        bot.update!(funds_return_status: "failed")
        return
      end

      result = EthersService.send_ETH(
        bot_wallet,
        to_address,
        send_amount,
        provider_url
      )

      unless result["success"] && result["txHash"].present?
        if attempt < MAX_ATTEMPTS
          Rails.logger.warn "[BotFunds::SendEthBackJob] send ETH failed for Bot##{bot.id}: #{result["error"]}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(bot.id, attempt + 1)
        else
          Rails.logger.error "[BotFunds::SendEthBackJob] Giving up for Bot##{bot.id} after #{MAX_ATTEMPTS} attempts"
          bot.update!(funds_return_status: "failed")
        end
        return
      end

      tx_hash = result["txHash"]
      Rails.logger.info "[BotFunds::SendEthBackJob] submitted send ETH tx for Bot##{bot.id} (tx: #{tx_hash})"

      bot.update!(
        funds_return_status: "pending",
        funds_return_tx_hash: tx_hash
      )

      BotFunds::SendEthBackConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(bot.id)
    rescue => e
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[BotFunds::SendEthBackJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(bot_id, attempt + 1)
      else
        Rails.logger.error "[BotFunds::SendEthBackJob] Fatal error for Bot##{bot_id}: #{e.class} #{e.message}"
        bot&.update!(funds_return_status: "failed")
        raise e
      end
    end
  end
end