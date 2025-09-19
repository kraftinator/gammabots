# app/services/gas_reserve_service.rb
class GasReserveService
  # Hardcoded per-chain targets
  DEFAULT_TARGETS = {
    'base_mainnet' => BigDecimal('0.00002')
    #'base_mainnet' => BigDecimal('0.0042')
  }.freeze

  # Public: compute the gas top-up needed for this user before creating a bot
  #
  # Params:
  # - user: User            (must respond to wallet_for_chain)
  # - chain: Chain          (must have .name)
  # - bot_amount_eth: BigDecimal
  # - provider_url: String  (RPC endpoint for this chain)
  #
  # Returns Hash with ETH BigDecimals and wei strings.
  def self.needed_for(user:, chain:, bot_amount_eth:, provider_url:)
    wallet = user.wallet_for_chain(chain)
    raise "No wallet for chain #{chain.name}" unless wallet&.address.present?

    target_eth   = DEFAULT_TARGETS.fetch(chain.name) { BigDecimal('0') }
    balance_eth  = BigDecimal(EthersService.get_balance(wallet.address, provider_url).to_s)

    needed_topup_eth    = [target_eth - balance_eth, 0].max
    total_required_eth  = bot_amount_eth + needed_topup_eth

    {
      target_eth:          target_eth,
      current_balance_eth: balance_eth,
      needed_topup_eth:    needed_topup_eth,
      total_required_eth:  total_required_eth,
      target_wei:          eth_to_wei_s(target_eth),
      current_balance_wei: eth_to_wei_s(balance_eth),
      needed_topup_wei:    eth_to_wei_s(needed_topup_eth),
      total_required_wei:  eth_to_wei_s(total_required_eth)
    }
  end

  def self.eth_to_wei_s(eth_bd)
    (eth_bd * BigDecimal('1000000000000000000')).to_i.to_s
  end
end