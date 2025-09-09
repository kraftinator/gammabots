# app/jobs/confirm_funding_job.rb
class ConfirmFundingJob < ApplicationJob
  RETRY_DELAY = 30.seconds
  MAX_TRIES   = 10

  def perform(bot_id, attempts = 1)
    bot = Bot.find_by(id: bot_id)
    return unless bot&.status == 'pending_funding'

    # We can’t verify without a tx hash
    if bot.funding_tx_hash.blank?
      Rails.logger.info "[ConfirmFundingJob] Bot##{bot_id} has no funding_tx_hash yet; retrying (#{attempts}/#{MAX_TRIES})"
      return retry_later(bot_id, attempts)
    end

    provider_url  = bot.provider_url
    deposit_addr  = bot.user.wallet_for_chain(bot.chain).address # or bot.deposit_address if you have it

    details = nil
    begin
      # Expecting a hash with keys: 'fromAddress', 'toAddress', 'amountEth', 'status', 'blockNumber', 'txHash'
      details = EthersService.get_ETH_transfer_details(bot.funding_tx_hash, provider_url)
    rescue => e
      Rails.logger.warn "[ConfirmFundingJob] RPC error for Bot##{bot_id} tx=#{bot.funding_tx_hash}: #{e.class}: #{e.message}"
      return retry_later(bot_id, attempts)
    end

    # If provider returned nothing (unknown/pending), back off and retry
    if details.blank? || details['status'].nil?
      Rails.logger.info "[ConfirmFundingJob] Pending/unknown receipt for Bot##{bot_id} tx=#{bot.funding_tx_hash} (#{attempts}/#{MAX_TRIES})"
      return retry_later(bot_id, attempts)
    end

    # If the tx is mined but reverted, fail fast
    if details['status'].to_i == 0
      Rails.logger.warn "[ConfirmFundingJob] Reverted tx for Bot##{bot_id} tx=#{bot.funding_tx_hash}; marking funding_failed"
      bot.update!(status: 'funding_failed')
      return
    end

    # Mined with status=1 — verify destination, amount, and hash match what we expect
    to_ok    = normalize_addr(details['toAddress'])   == normalize_addr(deposit_addr)
    hash_ok  = details['txHash'].to_s.downcase        == bot.funding_tx_hash.to_s.downcase
    amount_ok = begin
      BigDecimal(details['amountEth'].to_s) == bot.initial_buy_amount
    rescue
      false
    end

    unless to_ok && hash_ok && amount_ok
      Rails.logger.warn "[ConfirmFundingJob] Mismatch for Bot##{bot_id}: " \
                        "to_ok=#{to_ok} hash_ok=#{hash_ok} amount_ok=#{amount_ok} " \
                        "(to: #{details['toAddress']} expected: #{deposit_addr}; " \
                        "amountEth: #{details['amountEth']} expected: #{bot.initial_buy_amount}; " \
                        "txHash: #{details['txHash']} expected: #{bot.funding_tx_hash})"
      bot.update!(status: 'funding_failed')
      return
    end

    # Optional extra guard: check the custodial wallet balance covers amount (can be omitted if you trust the receipt)
    # total_eth_balance = EthersService.get_balance(deposit_addr, provider_url)
    # if BigDecimal(details['amountEth']) > BigDecimal(total_eth_balance)
    #   Rails.logger.warn "[ConfirmFundingJob] Balance check failed for Bot##{bot_id}"
    #   bot.update!(status: 'funding_failed')
    #   return
    # end

    # All checks passed — mark funded/active
    bot.update!(
      status:                'funded',
      funder_address:        normalize_addr(details['fromAddress']),
      funding_confirmed_at:  Time.current
    )
    Rails.logger.info "[ConfirmFundingJob] Bot##{bot_id} funding confirmed; now active"
    ConvertToWethJob.perform_later(bot.id)
  end

  private

  def retry_later(bot_id, attempts)
    if attempts < MAX_TRIES
      self.class.set(wait: RETRY_DELAY).perform_later(bot_id, attempts + 1)
    else
      Rails.logger.warn "[ConfirmFundingJob] Giving up after #{MAX_TRIES} tries for Bot##{bot_id}; marking expired"
      Bot.where(id: bot_id, status: 'pending_funding').update_all(status: 'expired')
    end
  end

  def normalize_addr(addr)
    addr.to_s.strip.downcase
  end
end