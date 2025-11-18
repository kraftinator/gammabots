class RefundFundingJob < ApplicationJob
  RETRY_DELAY  = 30.seconds
  MAX_ATTEMPTS = 10
  CONFIRMATION_DELAY = 5.seconds

  def perform(bot_id, refund_eth_str, attempt = 1)
    bot = Bot.find_by(id: bot_id)
    return unless bot
    return unless bot.status == 'funding_failed'
    return unless refund_eth_str

    bot_wallet   = bot.user.wallet_for_chain(bot.chain)
    provider_url = bot.provider_url
    to_address   = bot.funder_address

    refund_eth = BigDecimal(refund_eth_str.to_s)

    result = EthersService.send_ETH(
      bot_wallet,
      to_address,
      refund_eth.to_s,
      provider_url
    )

    unless result["success"] && result["txHash"].present?
      if attempt < MAX_ATTEMPTS
        Rails.logger.warn "[RefundFundingJob] refund ETH failed for Bot##{bot.id}: #{result["error"]}; retrying (#{attempt}/#{MAX_ATTEMPTS})"
        self.class.set(wait: RETRY_DELAY).perform_later(bot.id, attempt + 1)
      else
        Rails.logger.error "[RefundFundingJob] Giving up for Bot##{bot.id} after #{MAX_ATTEMPTS} attempts"
      end
      return
    end
  end
end