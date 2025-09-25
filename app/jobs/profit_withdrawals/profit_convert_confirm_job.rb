module ProfitWithdrawals
  class ProfitConvertConfirmJob < ApplicationJob
    RETRY_DELAY  = 30.seconds
    MAX_ATTEMPTS = 10

    def perform(withdrawal_id, attempt = 1)
      withdrawal = ProfitWithdrawal.find_by(id: withdrawal_id)
      return unless withdrawal
      return unless withdrawal.convert_status == "pending" && withdrawal.convert_tx_hash.present?

      bot          = withdrawal.bot
      bot_wallet   = bot.user.wallet_for_chain(bot.chain)
      provider_url = bot.provider_url
      tx_hash      = withdrawal.convert_tx_hash

      receipt =
        if withdrawal.payout_token_id.nil?
          # ETH case → unwrap receipt
          EthersService.get_wrap_receipt(tx_hash, provider_url)
        else
          # ERC-20 case → swap receipt
          weth         = Token.find_by!(chain: bot.chain, symbol: "WETH")
          payout_token = withdrawal.payout_token
          token_pair   = TokenPair.find_by!(chain: bot.chain, base_token: payout_token, quote_token: weth)

          EthersService.get_transaction_receipt(tx_hash, bot_wallet.address, token_pair, provider_url)
        end

      if receipt.nil?
        if attempt < MAX_ATTEMPTS
          Rails.logger.info "[ProfitWithdrawals::ProfitConvertConfirmJob] Withdrawal##{withdrawal.id} convert still pending (#{attempt}/#{MAX_ATTEMPTS})"
          self.class.set(wait: RETRY_DELAY).perform_later(withdrawal.id, attempt + 1)
        else
          Rails.logger.error "[ProfitWithdrawals::ProfitConvertConfirmJob] Giving up on Withdrawal##{withdrawal.id} convert after #{MAX_ATTEMPTS} attempts"
          withdrawal.update!(convert_status: "failed")
        end
        return
      end

      if receipt["status"].to_i == 1
        payout_amount =
          if withdrawal.payout_token_id.nil?
            # ETH case to unwrap = amount_withdrawn
            withdrawal.amount_withdrawn
          else
            # ERC-20 case to amountOut from swap
            BigDecimal(receipt["amountOut"].to_s)
          end

        withdrawal.update!(
          convert_status: "converted",
          payout_amount:  payout_amount,
          converted_at:   Time.current
        )

        Rails.logger.info "[ProfitWithdrawals::ProfitConvertConfirmJob] convert confirmed for Withdrawal##{withdrawal.id} (tx: #{tx_hash})"

        # Kick off transfer job
        ProfitWithdrawals::ProfitTransferJob.perform_later(withdrawal.id)
      else
        Rails.logger.error "[ProfitWithdrawals::ProfitConvertConfirmJob] convert tx reverted for Withdrawal##{withdrawal.id} (tx: #{tx_hash})"
        withdrawal.update!(convert_status: "failed")
      end
    end
  end
end