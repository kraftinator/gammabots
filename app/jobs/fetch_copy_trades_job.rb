class FetchCopyTradesJob
  include Sidekiq::Job

  def perform
    chain = Chain.find_by(name: 'base_mainnet')
    provider_url = ProviderUrlService.get_provider_url(chain.name)
    current_block = EthersService.current_block_number(provider_url)
    last_processed_block = EthersService.last_processed_block_number(chain.id, provider_url)

    copy_trade_addresses.each do |wallet_address|
      swaps = EthersService.get_swaps(wallet_address, last_processed_block, current_block, provider_url)
      swaps.each do |swap|
        next unless valid_swap?(swap)
        PendingCopyTrade.create!(
          chain: chain,
          wallet_address: wallet_address,
          token_address: swap["rawContract"]["address"].downcase,
          amount_out: swap["value"],
          tx_hash: swap["hash"],
          block_number: swap["blockNum"].to_i(16),  # Convert hex to integer
          status: 'pending'
        )
      end
    end

    EthersService.update_last_processed_block(chain.id, current_block)
  end

  private

  def copy_trade_addresses
    Bot.copy_bots
      .active
      .where(token_pair_id: nil)
      .distinct
      .pluck(:copy_wallet_address)
  end

  def valid_swap?(swap)
    return false unless swap.is_a?(Hash)
    
    # Check required fields exist
    required_fields = ["hash", "blockNum", "value", "rawContract"]
    return false unless required_fields.all? { |field| swap.key?(field) }

    # Filter out by symbol
    excluded_assets = ["WETH", "ETH", "USDC", "USDT", "DAI"]
    return false if excluded_assets.include?(swap["asset"])
    
    # Check rawContract has address
    return false unless swap["rawContract"].is_a?(Hash) && swap["rawContract"]["address"].present?
    
    # Check hash is valid format (0x + 64 hex chars)
    return false unless swap["hash"].match?(/\A0x[a-fA-F0-9]{64}\z/)
    
    # Check token address is valid format (0x + 40 hex chars)
    return false unless swap["rawContract"]["address"].match?(/\A0x[a-fA-F0-9]{40}\z/)
    
    # Check value is positive
    return false unless swap["value"].to_f > 0
    
    # Check category is erc20 (should always be based on our query)
    return false unless swap["category"] == "erc20"
    
    true
  end
end