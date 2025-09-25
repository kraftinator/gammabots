module ProfitWithdrawals
  class ProfitTransferJob < ApplicationJob
    RETRY_DELAY        = 30.seconds
    MAX_ATTEMPTS       = 10
    CONFIRMATION_DELAY = 5.seconds

    def perform(withdrawal_id, attempt = 1)
      withdrawal = ProfitWithdrawal.find_by(id: withdrawal_id)
      return unless withdrawal
      return unless withdrawal.convert_status == "converted"
      return if withdrawal.transfer_status == "transferred" || withdrawal.transfer_status == "failed"

      bot          = withdrawal.bot
      bot_wallet   = bot.user.wallet_for_chain(bot.chain)
      provider_url = bot.provider_url
      to_address   = bot.user.profit_withdrawal_address

      if to_address.blank?
        Rails.logger.error "[ProfitWithdrawals::ProfitTransferJob] Withdrawal##{withdrawal.id} has no profit_withdrawal_address, cannot send funds"
        withdrawal.update!(transfer_status: "failed")
        return
      end

      decimals = withdrawal.payout_token_id.nil? ? 18 : withdrawal.payout_token.decimals
      send_amount = withdrawal.payout_amount.to_d.round(decimals, BigDecimal::ROUND_DOWN)
      return if send_amount <= 0

      result =
        if withdrawal.payout_token_id.nil?
          # ETH case
          EthersService.send_ETH(
            bot_wallet,
            to_address,
            send_amount,
            provider_url
          )
        else
          # ERC-20 case
          token = withdrawal.payout_token
          EthersService.send_erc20(
            bot_wallet,
            token.contract_address,
            to_address,
            send_amount,
            token.decimals,
            provider_url
          )
        end

      unless result["success"] && result["txHash"].present?
        if attempt < MAX_ATTEMPTS
          Rails.logger.warn "[ProfitWithdrawals::ProfitTransferJob] transfer failed for Withdrawal##{withdrawal.id}: #{result["error"]}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(withdrawal.id, attempt + 1)
        else
          Rails.logger.error "[ProfitWithdrawals::ProfitTransferJob] Giving up for Withdrawal##{withdrawal.id} after #{MAX_ATTEMPTS} attempts"
          withdrawal.update!(transfer_status: "failed")
        end
        return
      end

      tx_hash = result["txHash"]
      Rails.logger.info "[ProfitWithdrawals::ProfitTransferJob] submitted transfer tx for Withdrawal##{withdrawal.id} (tx: #{tx_hash})"

      withdrawal.update!(
        transfer_status: "pending",
        transfer_tx_hash: tx_hash
      )

      ProfitWithdrawals::ProfitTransferConfirmJob.set(wait: CONFIRMATION_DELAY).perform_later(withdrawal.id)
    rescue => e
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[ProfitWithdrawals::ProfitTransferJob] #{e.class}: #{e.message}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(withdrawal_id, attempt + 1)
      else
        Rails.logger.error "[ProfitWithdrawals::ProfitTransferJob] Fatal error for Withdrawal##{withdrawal_id}: #{e.class} #{e.message}"
        withdrawal&.update!(transfer_status: "failed")
        raise e
      end
    end
  end
end