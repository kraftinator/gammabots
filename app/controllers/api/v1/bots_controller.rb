module Api
  module V1
    class BotsController < Api::BaseController
      before_action :require_quick_auth!
      
      def index
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        @bots = current_user.bots.active.default_bots
        formatted_bots = @bots.map do |bot|
          {
            bot_id: bot.id.to_s,
            token_symbol: bot.token_pair.base_token.symbol,
            strategy_id: bot.strategy.id.to_s
          }
        end
        
        render json: formatted_bots
      end
    end
  end
end