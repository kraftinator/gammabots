
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

        render json: {
          active_bots: metrics.active_bots,
          tvl: metrics.tvl_usd,
          volume_24h: metrics.volume_24h_usd,
          strategies: metrics.strategies_count,
          total_profits: metrics.total_profits_usd,
          trades_executed: metrics.trades_executed,
          last_updated: metrics.created_at.iso8601
        }
      end
    end
  end
end