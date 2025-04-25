# app/jobs/approval_job.rb
class ApprovalJob < ApplicationJob
  def perform(trade_id)
    trade = Trade.find(trade_id)
    bot = trade.bot
    
    token_address = bot.token_pair.base_token.contract_address
    provider_url = bot.provider_url
    private_key = bot.user.wallet_for_chain(bot.chain).private_key

    is_infinite_approval = EthersService.is_infinite_approval(
      private_key,
      token_address,
      provider_url
    )

    puts "is_infinite_approval: #{is_infinite_approval}"
    return if is_infinite_approval

    EthersService.infinite_approve(
      private_key,
      token_address,
      provider_url
    )
  end
end
