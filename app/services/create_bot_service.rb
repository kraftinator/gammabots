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
  def self.call(user_id:, token_contract_address:, initial_amount:, strategy_token_id:, chain_name:)
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

    # Get Token. If not found, create it by pulling data from Uniswap.
    token = Token.find_by(chain: chain, contract_address: token_contract_address)
    if token.nil?
      token = Token.create_from_contract_address(token_contract_address, chain)
      raise ArgumentError, "Token creation failed" unless token
    end

    # Get Quote Token - assume it's WETH
    quote_token = Token.find_by(chain: chain, symbol: 'WETH')
    raise ArgumentError, "Invalid quote token" unless quote_token

    # Find Trading Pair (base token = token, quote token = WETH)
    token_pair = TokenPair.find_by(chain: chain, base_token: token, quote_token: quote_token)
    if token_pair.nil?
      token_pair = TokenPair.create!(chain: chain, base_token: token, quote_token: quote_token)
      # Initialize the token pair's price by calling latest_price
      token_pair.latest_price
    end

    # Create the Bot with the provided parameters.
    bot = Bot.create!(
      chain: chain,
      strategy: strategy,
      user: user,
      token_pair: token_pair,
      quote_token_amount: amount,
      created_at_price: token_pair.latest_price,
      lowest_price_since_creation: token_pair.latest_price
    )

    bot
  end
end
