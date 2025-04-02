module Api
  module V1
    class UsersController < Api::BaseController      
      
      def show
        user_exists = User.exists?(farcaster_id: params[:id])
        render json: { exists: user_exists }, status: :ok
      end

      def create
        chain = Chain.find_by(name: "base_mainnet")
        user = User.find_or_initialize_by(farcaster_id: params[:fid])
        
        if user.new_record?
          user.created_by_signature = params[:signature]
          user.created_by_wallet = params[:address]
                    
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