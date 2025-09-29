# app/jobs/fee_collections/fee_distribute_job.rb
module FeeCollections
  class FeeDistributeJob < ApplicationJob
    TREASURY_SPLIT = BigDecimal("0.75")
    STRATEGY_SPLIT = BigDecimal("0.25")

    def perform(fee_collection_id)
      fee = FeeCollection.find_by(id: fee_collection_id)
      return unless fee&.unwrap_unwrapped?

      bot   = fee.trade.bot
      chain = bot.chain
      total_amount = fee.amount.to_d

      treasury_share = (total_amount * TREASURY_SPLIT).round(18, BigDecimal::ROUND_DOWN)
      strategy_share = (total_amount * STRATEGY_SPLIT).round(18, BigDecimal::ROUND_DOWN)

      # Reserve adjustment
      router_wallet = Wallet.find_by!(kind: "router", chain: chain)
      needed_topup  = GasReserveService.topup_needed_for_wallet(wallet: router_wallet, provider_url: bot.provider_url)

      if needed_topup > 0 && treasury_share > needed_topup
        treasury_share -= needed_topup
        Rails.logger.info "[FeeDistributeJob] Deducted #{needed_topup} ETH from treasury share to top up router reserve"
      end

      # 1. Treasury recipient
      treasury_wallet = Wallet.find_by!(kind: "treasury", chain: chain)
      treasury = fee.fee_recipients.create!(
        amount: treasury_share,
        recipient_type: "platform",
        recipient_address:  treasury_wallet.address,
        status: "pending"
      )

      # 2. Strategy recipient
      strategy = fee.fee_recipients.create!(
        amount: strategy_share,
        recipient_type: "strategy_owner",
        recipient_address: bot.strategy.current_owner_address,
        status: "pending"
      )

      # Queue payout jobs
      FeePayoutJob.set(wait: 0.seconds).perform_later(treasury.id)
      FeePayoutJob.set(wait: 5.seconds).perform_later(strategy.id)
    end
  end
end