class PayoutJob < ApplicationJob
  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(withdrawal_id)
    withdrawal = ProfitWithdrawal.find(withdrawal_id)
    bot = withdrawal.bot
    cycle = withdrawal.bot_cycle
    provider_url = bot.provider_url

    base_token = Token.find_by(chain: bot.chain, symbol: 'USDC')
    quote_token = Token.find_by(chain: bot.chain, symbol: 'WETH')
    token_pair = TokenPair.find_by(chain: bot.chain, base_token: base_token, quote_token: quote_token)

    result = EthersService.buy_with_min_amount(
      bot.user.wallet_for_chain(bot.chain),
      withdrawal.amount_withdrawn, # Amount to spend
      token_pair.quote_token.contract_address, # Token used for buying
      token_pair.base_token.contract_address,  # Token being bought
      token_pair.quote_token.decimals,
      token_pair.base_token.decimals,
      token_pair.fee_tier,
      0,
      provider_url
    )

    sleep 5
    receipt = poll_receipt(result['txHash'], token_pair, 60, provider_url)
    
    amount_out = BigDecimal(receipt["amountOut"].to_s)
    amount_in = BigDecimal(receipt["amountIn"].to_s)
    return unless valid_transaction?(receipt, amount_in, amount_out)

    transfer_result = EthersService.send_erc20(
      bot.user.wallet_for_chain(bot.chain),
      token_pair.base_token.contract_address,
      bot.user.created_by_wallet,
      amount_out * 0.9999999999,
      token_pair.base_token.decimals,
      provider_url
    )

    # transfer_result["success"]
  end

  private

  def poll_receipt(tx_hash, token_pair, timeout_seconds, provider_url)
    deadline = Time.now + timeout_seconds
    loop do
      receipt = EthersService.get_transaction_receipt(tx_hash, token_pair, provider_url)
      return receipt if receipt
      raise "Timed out waiting for #{tx_hash}" if Time.now > deadline
      sleep 5
    end
  end

  def valid_transaction?(transaction_receipt, amount_in, amount_out)
    transaction_receipt["status"] == 1 && amount_in.positive? && amount_out.positive?
  end
end