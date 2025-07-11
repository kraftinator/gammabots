# app/services/create_bot_service.rb
class CreateBotService
  # Call with:
  #   CreateBotService.call(
  #     user_id: 1,
  #     token_contract_address: "0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed",
  #     initial_amount: "0.0005",
  #     strategy_token_id: 4,
  #     chain_name: "base_mainnet"
  #   )
  def self.call(user_id:, token_contract_address:, initial_amount:, strategy_token_id:, moving_avg_minutes:, chain_name:)
    # Get Chain
    chain = Chain.find_by(name: chain_name)
    raise ArgumentError, "Invalid chain" unless chain

    # Get Strategy
    strategy = Strategy.find_by(nft_token_id: strategy_token_id)
    raise ArgumentError, "Invalid strategy" unless strategy

    # Get User
    user = User.find_by(id: user_id)
    raise ArgumentError, "Invalid user" unless user

    # Parse initial_amount into a BigDecimal for precision
    amount = BigDecimal(initial_amount.to_s)

    # Normalize the token contract address to lowercase
    token_contract_address = token_contract_address.downcase

    token_pair = CreateTokenPairService.call(
      token_address: token_contract_address,
      chain: chain
    )

    unless token_pair
      puts "Cannot create token pair."
      return nil
    end
    
    bot = Bot.create!(
      chain: chain,
      strategy: strategy,
      moving_avg_minutes: moving_avg_minutes,
      user: user,
      token_pair: token_pair,
      initial_buy_amount: amount
    )
    if bot
      current_price = token_pair.latest_price
      moving_avg = token_pair.moving_average(moving_avg_minutes.to_i)
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
