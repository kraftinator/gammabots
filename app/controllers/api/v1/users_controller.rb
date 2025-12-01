module Api
  module V1
    class UsersController < Api::BaseController    
      before_action :require_quick_auth!  
      
      def show
        user_exists = User.exists?(farcaster_id: params[:id])
        render json: { exists: user_exists }, status: :ok
      end

      def create
        chain = Chain.find_by(name: "base_mainnet")

        user = User.find_or_initialize_by(farcaster_id: current_fid)
        
        if user.new_record?
          user.created_by_signature = params[:signature]
          user.created_by_wallet    = params[:wallet_address]
          user.farcaster_username   = params[:farcaster_username]
          user.farcaster_avatar_url = params[:farcaster_avatar]

          if params[:signed_at].present?
            begin
              user.signup_signed_at = Time.iso8601(params[:signed_at])
            rescue ArgumentError
              Rails.logger.warn("Invalid signed_at format: #{params[:signed_at].inspect}")
              # optional: leave signup_signed_at nil or set to Time.current
            end
          end
                    
          if user.save
            random_wallet = EthersService.generate_wallet

            user.wallets.create(
              chain: chain,
              private_key: random_wallet["privateKey"],
              address: random_wallet["address"]
            )

            render json: { wallet_address: user.wallet_for_chain(chain).address }, status: :created
          else
            render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { wallet_address: user.wallet_for_chain(chain).address }, status: :ok
        end
      end

    end
  end
end