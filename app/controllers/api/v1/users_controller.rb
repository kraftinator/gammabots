module Api
  module V1
    class UsersController < Api::BaseController      
      
      def show
        user_exists = User.exists?(farcaster_id: params[:id])
        render json: { exists: user_exists }, status: :ok
      end

      def create
        #user.wallet_for_chain(bot.chain).private_key
        chain = Chain.find_by(name: "base_mainnet")
        user = User.find_or_initialize_by(farcaster_id: params[:fid])
        
        if user.new_record?
          #user.wallet_address = params[:address]
          #user.signature = params[:signature]
          render json: { wallet_address: "fake_address1" }, status: :ok
          
          #if user.save
          #  render json: { wallet_address: user.wallet_address }, status: :created
          #else
          #  render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
          #end
        else
          #render json: { wallet_address: 'user.wallet_address' }, status: :ok
          render json: { wallet_address: user.wallet_for_chain(chain).wallet_address }, status: :ok
        end
      end

    end
  end
end