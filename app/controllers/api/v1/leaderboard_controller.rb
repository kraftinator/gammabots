# app/controllers/api/v1/leaderboard_controller.rb
module Api
  module V1
    class LeaderboardController < Api::BaseController
      after_action :log_response_for_debugging

      # GET /api/v1/leaderboard/bots
      def bots
        bots = Bot
          .inactive
          .default_bots
          .includes(:user, :strategy, token_pair: :base_token)
          .where('created_at >= ?', Date.new(2025, 7, 1))
          .to_a

        bots.reject! { |bot| bot.completed_trade_count == 0 }

        # Compute realized performance
        bots_with_perf = bots.map do |bot|
          pct = bot.profit_percentage(include_profit_withdrawals: true)
          pct = 0.0 if pct.nil?
          [bot, pct]
        end

        # Sort descending by realized PnL
        bots_with_perf.sort_by! { |(_bot, pct)| -pct }

        response_bots = bots_with_perf.each_with_index.map do |(bot, performance_pct), idx|
          user     = bot.user
          strategy = bot.strategy
          token    = bot.token_pair&.base_token

          end_time = bot.last_action_at || bot.updated_at
          active_seconds = (end_time - bot.created_at).to_i

          {
            rank: idx + 1,
            bot_id: bot.id.to_s,
            token_symbol: token&.symbol,
            strategy_id: strategy&.nft_token_id,
            owner_farcaster_username: user&.farcaster_username,
            owner_farcaster_avatar_url: user&.farcaster_avatar_url,
            active_seconds: active_seconds,
            performance_pct: performance_pct,
            cloneable: current_user.present?
          }
        end

        render json: {
          timeframe: "all_time",
          bots: response_bots
        }, status: :ok
      end

      private

      def log_response_for_debugging
        Rails.logger.info "[LEADERBOARD] RESPONSE status=#{response.status} body=#{response.body.inspect}"
      end
    end
  end
end