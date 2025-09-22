# app/services/create_bot_service.rb
class CreateBotService
  # Example:
  # CreateBotService.call(
  #   user_id: 1,
  #   token_contract_address: "0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed",
  #   initial_amount: "0.0005",
  #   strategy_token_id: 4,
  #   moving_avg_minutes: 6,
  #   chain_name: "base_mainnet",
  #   profit_share: "0.40",       # optional
  #   profit_threshold: "0.08"    # optional
  # )
  def self.call(
    user_id:,
    token_contract_address:,
    initial_amount:,
    strategy_token_id:,
    moving_avg_minutes:,
    chain_name:,
    profit_share: nil,
    profit_threshold: nil,
    funder_address:
  )
    # == Look-ups & validations ==
    chain    = Chain.find_by(name: chain_name)           or raise ArgumentError, "Invalid chain"
    strategy = Strategy.find_by(nft_token_id: strategy_token_id) or raise ArgumentError, "Invalid strategy"
    user     = User.find_by(id: user_id)                 or raise ArgumentError, "Invalid user"

    amount = BigDecimal(initial_amount.to_s)
    token_contract_address = token_contract_address.downcase

    token_pair = CreateTokenPairService.call(
      token_address: token_contract_address,
      chain: chain
    )
    return nil unless token_pair

    # == Build bot attributes ==
    bot_attrs = {
      chain: chain,
      strategy: strategy,
      moving_avg_minutes: moving_avg_minutes,
      user: user,
      token_pair: token_pair,
      initial_buy_amount: amount,
      status: 'active',
      funder_address: funder_address.downcase
    }
    bot_attrs[:profit_share]     = BigDecimal(profit_share.to_s)     if profit_share.present?
    bot_attrs[:profit_threshold] = BigDecimal(profit_threshold.to_s) if profit_threshold.present?

    # == Create bot ==
    bot = Bot.create!(bot_attrs)

    # == Seed first bot cycle ==
    if bot
      current_price = token_pair.latest_price
      moving_avg    = token_pair.moving_average(moving_avg_minutes.to_i)

      bot.bot_cycles.create!(
        started_at: Time.current,
        quote_token_amount: amount,
        created_at_price: current_price,
        lowest_price_since_creation: current_price,
        lowest_moving_avg_since_creation: moving_avg
      )
    end

    bot
  end
end