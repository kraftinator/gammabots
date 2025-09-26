class ConvertToWethJob < ApplicationJob
  queue_as :default
  RETRY_DELAY = 30.seconds
  MAX_TRIES   = 10

  # Submits the wrap tx and enqueues confirmation
  def perform(bot_id, attempts = 1)
    bot = Bot.find_by(id: bot_id)
    return unless bot&.status == 'funded' || bot&.status == 'converting_to_weth'

    # Move into converting state (idempotent)
    bot.update!(status: 'converting_to_weth') if bot.status == 'funded'

    provider_url = bot.provider_url
    wallet       = bot.user.wallet_for_chain(bot.chain)

    result = EthersService.convert_ETH_to_WETH(
      wallet,
      provider_url,
      bot.initial_buy_amount # ETH (BigDecimal)
    )

    unless result.is_a?(Hash) && result['success']
      raise "wrap failed: #{result && result['error'] && result['error']['message']}"
    end

    # Persist tx hash and finalize
    bot.update!(
      weth_wrap_tx_hash: result['txHash'].downcase,
      weth_wrapped_at:   Time.current,
      status:            'active'
    )
    StartFirstCycleJob.perform_later(bot.id)
    Rails.logger.info "[ConvertToWethJob] Bot##{bot.id} wrap confirmed tx=#{result['txHash']} -> active"
  rescue => e
    if attempts < MAX_TRIES
      Rails.logger.warn "[ConvertToWethJob] #{e.class}: #{e.message}; retrying (#{attempts}/#{MAX_TRIES})"
      self.class.set(wait: RETRY_DELAY).perform_later(bot_id, attempts + 1)
    else
      Rails.logger.error "[ConvertToWethJob] Giving up for Bot##{bot_id}; marking conversion_failed"
      Bot.where(id: bot_id, status: 'converting_to_weth').update_all(status: 'conversion_failed')
    end
  end
end