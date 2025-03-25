module Api
  module V1
    class UsersController < Api::BaseController      
      
      def show
        user_exists = User.exists?(farcaster_id: params[:id])
        render json: { exists: user_exists }, status: :ok
      end

    end
  end
end