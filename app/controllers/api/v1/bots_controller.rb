module Api
  module V1
    class BotsController < ApplicationController
      # Skip CSRF protection for API endpoints
      skip_before_action :verify_authenticity_token
      
      def index
        @bots = Bot.active.all
        #render json: @bots
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