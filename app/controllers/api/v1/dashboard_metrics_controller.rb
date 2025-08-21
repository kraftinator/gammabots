
# app/controllers/api/v1/dashboard_metrics_controller.rb
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
    end
  end
end