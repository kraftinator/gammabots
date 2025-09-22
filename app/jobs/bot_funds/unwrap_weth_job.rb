module BotFunds
  class UnwrapWethJob < ApplicationJob
    RETRY_DELAY        = 30.seconds
    MAX_ATTEMPTS       = 10
    CONFIRMATION_DELAY = 5.seconds

    def perform(bot_id, attempt = 1)
      bot = Bot.find_by(id: bot_id)
      return unless bot

      cycle = bot.current_cycle
      return unless cycle

      unwrap_amount = cycle.quote_token_amount.to_d
      unwrap_amount = unwrap_amount.round(18, BigDecimal::ROUND_DOWN)
      return if unwrap_amount <= 0

      bot_wallet   = bot.user.wallet_for_chain(bot.chain)
      provider_url = bot.provider_url

      # mark status as pending on first attempt
      if attempt == 1 && bot.weth_unwrap_status.nil?
        bot.update!(weth_unwrap_status: "pending")
      end

      result = EthersService.convert_WETH_to_ETH(bot_wallet, provider_url, unwrap_amount)

      unless result["success"] && result["txHash"].present?
        if attempt < MAX_ATTEMPTS
          Rails.logger.warn "[BotFunds::UnwrapWETHJob] unwrap failed for Bot##{bot.id}: #{result["error"]}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(bot.id, attempt + 1)
        else
          Rails.logger.error "[BotFunds::UnwrapWETHJob] Giving up for Bot##{bot.id} after #{MAX_ATTEMPTS} attempts"
          bot.update!(weth_unwrap_status: "failed")
        end
        return
      end

      tx_hash = result["txHash"]
      bot.update!(weth_unwrap_tx_hash: tx_hash, weth_unwrapped_amount: unwrap_amount)

      Rails.logger.info "[BotFunds::UnwrapWETHJob] submitted unwrap tx for Bot##{bot.id} (tx: #{tx_hash})"

      # Kick off confirmation job
      BotFunds::UnwrapWethConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(bot.id, tx_hash)
    rescue => e
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[BotFunds::UnwrapWETHJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(bot_id, attempt + 1)
      else
        Rails.logger.error "[BotFunds::UnwrapWETHJob] Fatal error for Bot##{bot_id}: #{e.class} #{e.message}"
        bot.update!(weth_unwrap_status: "failed") if bot
        raise e
      end
    end
  end
end