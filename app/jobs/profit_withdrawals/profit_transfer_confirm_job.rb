module ProfitWithdrawals
  class ProfitTransferConfirmJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10

    def perform(withdrawal_id, attempt = 1)
      withdrawal = ProfitWithdrawal.find_by(id: withdrawal_id)
      return unless withdrawal
      return unless withdrawal.transfer_status == "pending" && withdrawal.transfer_tx_hash.present?

      bot          = withdrawal.bot
      bot_wallet   = bot.user.wallet_for_chain(bot.chain)
      provider_url = bot.provider_url
      tx_hash      = withdrawal.transfer_tx_hash

      receipt =
        if withdrawal.payout_token_id.nil?
          # ETH transfer
          EthersService.get_ETH_transfer_details(tx_hash, provider_url)
        else
          # ERC-20 transfer
          token = withdrawal.payout_token
          EthersService.get_transfer_receipt(tx_hash, provider_url)
        end

      if receipt.nil?
        if attempt < MAX_ATTEMPTS
          Rails.logger.info "[ProfitWithdrawals::ProfitTransferConfirmJob] Withdrawal##{withdrawal.id} transfer still pending (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(withdrawal.id, attempt + 1)
        else
          Rails.logger.error "[ProfitWithdrawals::ProfitTransferConfirmJob] Giving up on Withdrawal##{withdrawal.id} transfer after #{MAX_ATTEMPTS} attempts"
          withdrawal.update!(transfer_status: "failed")
        end
        return
      end

      if receipt["status"].to_i == 1
        withdrawal.update!(
          transfer_status: "transferred",
          transferred_at:  Time.current
        )
        Rails.logger.info "[ProfitWithdrawals::ProfitTransferConfirmJob] transfer confirmed for Withdrawal##{withdrawal.id} (tx: #{tx_hash})"
      else
        Rails.logger.error "[ProfitWithdrawals::ProfitTransferConfirmJob] transfer tx reverted for Withdrawal##{withdrawal.id} (tx: #{tx_hash})"
        withdrawal.update!(transfer_status: "failed")
      end
    end
  end
end