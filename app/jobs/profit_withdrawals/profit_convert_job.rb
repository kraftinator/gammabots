module ProfitWithdrawals
  class ProfitConvertJob < ApplicationJob
    RETRY_DELAY        = 30.seconds
    MAX_ATTEMPTS       = 10
    CONFIRMATION_DELAY = 5.seconds
    MAX_SLIPPAGE       = 50
    ZERO_EX_API_KEY    = Rails.application.credentials.dig(:zero_ex, :api_key)

    def perform(withdrawal_id, attempt = 1)
      withdrawal = ProfitWithdrawal.find_by(id: withdrawal_id)
      return unless withdrawal

      bot = withdrawal.bot
      return unless bot

      bot_wallet   = bot.user.wallet_for_chain(bot.chain)
      provider_url = bot.provider_url

      amount = withdrawal.amount_withdrawn.to_d.round(18, BigDecimal::ROUND_DOWN)
      return if amount <= 0

      result =
        if withdrawal.payout_token_id.nil?
          # ETH case to unwrap WETH
          weth = Token.find_by!(chain: bot.chain, symbol: "WETH")
          EthersService.convert_WETH_to_ETH(bot_wallet, provider_url, amount)
        else
          # ERC-20 case to swap WETH  payout_token
          weth         = Token.find_by!(chain: bot.chain, symbol: "WETH")
          payout_token = withdrawal.payout_token
          token_pair   = TokenPair.find_by!(chain: bot.chain, base_token: payout_token, quote_token: weth)

          EthersService.swap(
            bot_wallet, 
            token_pair.quote_token.contract_address,
            token_pair.base_token.contract_address,
            amount,
            token_pair.quote_token.decimals,
            token_pair.base_token.decimals,
            MAX_SLIPPAGE,
            ZERO_EX_API_KEY, 
            provider_url,
            0
          )
        end

      unless result["success"] && result["txHash"].present?
        if attempt < MAX_ATTEMPTS
          Rails.logger.warn "[ProfitWithdrawals::ProfitConvertJob] convert failed for Withdrawal##{withdrawal.id}: #{result["error"]}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(withdrawal.id, attempt + 1)
        else
          Rails.logger.error "[ProfitWithdrawals::ProfitConvertJob] Giving up for Withdrawal##{withdrawal.id} after #{MAX_ATTEMPTS} attempts"
          withdrawal.update!(convert_status: "failed", error_message: result["error"])
        end
        return
      end

      tx_hash = result["txHash"]
      withdrawal.update!(convert_tx_hash: tx_hash, route: result["route"])

      Rails.logger.info "[ProfitWithdrawals::ProfitConvertJob] submitted convert tx for Withdrawal##{withdrawal.id} (tx: #{tx_hash})"

      # Kick off confirmation job
      ProfitWithdrawals::ProfitConvertConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(withdrawal.id)
    rescue => e
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[ProfitWithdrawals::ProfitConvertJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(withdrawal_id, attempt + 1)
      else
        Rails.logger.error "[ProfitWithdrawals::ProfitConvertJob] Fatal error for Withdrawal##{withdrawal_id}: #{e.class} #{e.message}"
        withdrawal.update!(convert_status: "failed", error_message: e.message) if withdrawal
        raise e
      end
    end
  end
end