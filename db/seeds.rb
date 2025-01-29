# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

base_chain = Chain.find_or_create_by!(
  name: "base_mainnet",
  native_chain_id: "8453",
  explorer_url: "https://basescan.org"
)

weth_token = Token.find_or_create_by!(
  chain: base_chain,
  symbol: "WETH",
  name: "Wrapped Ether",
  contract_address: "0x4200000000000000000000000000000000000006",
  decimals: 18
)

Token.find_or_create_by!(
  chain: base_chain,
  symbol: "USDC",
  name: "USD Coin",
  contract_address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  decimals: 6
)

degen_token = Token.find_or_create_by!(
  chain: base_chain,
  symbol: "DEGEN",
  name: "Degen",
  contract_address: "0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed",
  decimals: 18
)

TokenPair.find_or_create_by!(
  chain: base_chain,
  base_token: degen_token,
  quote_token: weth_token
)