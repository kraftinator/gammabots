# app/services/post_sell_service.rb
class PostSellService
  FEE_PCT = BigDecimal("0.003") # 0.3%

  def self.call(bot, trade)
    return unless trade.sell? && trade.completed?
    collect_fee(trade)
    handle_reset(bot)
    handle_liquidation(bot, trade)
    handle_fund_return(bot.reload)
  end

  class << self
    private

    def handle_liquidation(bot, trade)
      return unless bot.status == "liquidating"

      bot.transaction do
        bot.update!(
          active:        false,
          status:        "inactive",
          liquidated_at: Time.current
        )

        bot.current_cycle.update!(ended_at: Time.current)
      end
    end

    def collect_fee(trade)
      fee = (trade.amount_out.to_d * FEE_PCT).round(18, BigDecimal::ROUND_DOWN)

      fee_collection = trade.create_fee_collection!(
        amount: fee,
        status: "pending",
        unwrap_status: "pending"
      )

      # Subtract the fee from the bot cycle immediately
      if (cycle = trade.bot_cycle)
        new_quote_amount = cycle.quote_token_amount.to_d - fee
        cycle.update!(quote_token_amount: new_quote_amount)
      end

      FeeCollections::FeeUnwrapJob.perform_later(fee_collection.id)
    end

    def handle_reset(bot)
      return unless bot.current_cycle.reset_requested_at
      bot.process_reset
    end

    def handle_fund_return(bot)
      return if bot.active?
      Rails.logger.info "[PostSellService] Bot##{bot.id} inactive, scheduling return funds"
      bot.return_funds_to_user
    end
  end
end