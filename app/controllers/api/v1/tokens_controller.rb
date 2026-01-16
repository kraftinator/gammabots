# app/controllers/api/v1/tokens_controller.rb
module Api
  module V1
    class TokensController < Api::BaseController
      before_action :require_quick_auth!

      def lookup
        address = params[:address].to_s.strip.downcase

        unless address.match?(/\A0x[a-fA-F0-9]{40}\z/)
          return render json: {
            valid: false,
            error: "Invalid token address"
          }, status: :bad_request
        end

        chain = Chain.find_by!(name: "base_mainnet")
        chain_name = "Base"

        # 1️⃣ DB-first
        token = Token.find_by(chain: chain, contract_address: address)
        if token
          return render json: {
            valid: true,
            token_address: address,
            token_symbol: token.symbol,
            token_name: token.name,
            decimals: token.decimals,
            status: token.status,
            chain: chain_name
          }
        end

        # 2️⃣ Fallback to chain lookup (read-only)
        provider_url = ProviderUrlService.get_provider_url(chain.name)
        details = EthersService.get_token_details(address, provider_url)

        unless details
          return render json: {
            valid: false,
            error: "Token not found",
            chain: chain_name
          }, status: :not_found
        end

        render json: {
          valid: true,
          token_address: address,
          token_symbol: details["symbol"],
          token_name: details["name"],
          decimals: details["decimals"],
          status: "unverified",
          chain: chain_name
        }
      end
    end
  end
end