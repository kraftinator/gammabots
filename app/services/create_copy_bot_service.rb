# app/services/create_copy_bot_service.rb
class CreateCopyBotService
  # Call with:
  #   CreateCopyBotService.call(
  #     user_id: 1,
  #     copy_wallet_address: "XXXXX",
  #     initial_amount: "0.0005",
  #     strategy_token_id: 4,
  #     moving_avg_minutes: 5,
  #     chain_name: "base_mainnet"
  #   )
  def self.call(user_id:, copy_wallet_address:, initial_amount:, strategy_token_id:, moving_avg_minutes:, chain_name:)
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

    # Normalize the wallet address to lowercase
    copy_wallet_address = copy_wallet_address.downcase

    # Validate wallet address format
    unless copy_wallet_address.match?(/\A0x[a-fA-F0-9]{40}\z/)
      raise ArgumentError, "Invalid wallet address format"
    end
    
    # Create copy bot without token_pair (will be assigned when first trade detected)
    bot = Bot.create!(
      chain: chain,
      strategy: strategy,
      moving_avg_minutes: moving_avg_minutes,
      user: user,
      token_pair: nil,  # No token pair initially
      initial_buy_amount: amount,
      bot_type: 'copy',
      copy_wallet_address: copy_wallet_address
    )
    
    # Copy bots don't create an initial cycle - that happens when they detect a trade
    
    bot
  end
end