# app/controllers/api/v1/dashboard_metrics_controller.rb
include ActionView::Helpers::DateHelper

module Api
  module V1
    class DashboardMetricsController < Api::BaseController
      def index
        metrics = DashboardMetric.latest
        
        if metrics.nil?
          render json: { error: "No metrics available" }, status: 404
          return
        end

        @active_bots = Bot.active.default_bots
        @eth_price_usd = TokenPriceService.get_eth_price_in_usd(@active_bots.first&.chain)

        render json: {
          active_bots: metrics.active_bots,
          tvl: metrics.tvl_usd,
          volume_24h: metrics.volume_24h_usd,
          strategies: metrics.strategies_count,
          total_profits: metrics.total_profits_usd,
          trades_executed: metrics.trades_executed,
          popular_tokens: calculate_popular_tokens,
          recent_activity: calculate_recent_activity,
          last_updated: metrics.created_at.iso8601
        }
      end

      private
        
      def calculate_popular_tokens
        token_tvls = @active_bots.group_by { |bot| bot.token_pair.base_token.symbol }
                                 .transform_values { |bots| bots.sum(&:current_value) }
                                 .sort_by { |symbol, tvl| -tvl }
                                 .first(4)
                                 .to_h

        # Convert ETH to USD
        token_tvls.transform_values { |eth_amount| (eth_amount * @eth_price_usd).round(2) }
      end

      def calculate_recent_activity
        trades = Trade.joins(:bot)
                    .where(bot: Bot.default_bots)
                    .where(status: 'completed')
                    .order(executed_at: :desc)
                    .limit(4)

        trades.map do |trade|
          token_amount = trade.buy? ? trade.amount_out : trade.amount_in
          user = trade.bot.user
          
          {
            farcaster_username: user.farcaster_username,
            farcaster_avatar_url: user.farcaster_avatar_url,
            action: trade.trade_type.capitalize, # "Buy" or "Sell"
            amount: token_amount.round(0), # Token amount (not ETH)
            token_symbol: trade.bot.token_pair.base_token.symbol,
            strategy_id: trade.bot.strategy.nft_token_id,
            bot_id: trade.bot.id,
            time_ago: time_ago_in_words(trade.executed_at)
          }
        end
      end
    end
  end
end