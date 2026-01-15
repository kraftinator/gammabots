# app/controllers/api/v1/dashboard_metrics_controller.rb
include ActionView::Helpers::DateHelper

module Api
  module V1
    class DashboardMetricsController < Api::BaseController
      before_action :require_quick_auth!

      def index
        metrics = DashboardMetric.latest
        metrics_24h_ago = DashboardMetric.where("created_at <= ?", 24.hours.ago)
                                         .order(created_at: :desc)
                                         .first

        return render json: { error: "No metrics available" }, status: 404 if metrics.nil?

        user_bot_count = current_user&.bots&.active&.visible&.default_bots&.count || 0
        user_exists    = current_user.present?

        recent_activity = (metrics.recent_activity_json || []).map do |item|
          # Compute time_ago fresh, no DB required
          executed_at = Time.iso8601(item["executed_at"]) rescue nil
          item.merge(
            "time_ago" => executed_at ? time_ago_in_words(executed_at).sub(/^about\s+/, "") : nil
          )
        end

        render json: {
          active_bots: metrics.active_bots,
          user_bot_count: user_bot_count,
          user_exists: user_exists,

          active_bots_change_24h: calculate_percentage_change(metrics.active_bots, metrics_24h_ago&.active_bots),
          tvl: metrics.tvl_usd,
          tvl_change_24h: calculate_percentage_change(metrics.tvl_cents, metrics_24h_ago&.tvl_cents),
          volume_24h: metrics.volume_24h_usd,
          volume_24h_change_24h: calculate_percentage_change(metrics.volume_24h_cents, metrics_24h_ago&.volume_24h_cents),
          strategies: metrics.strategies_count,
          total_profits: metrics.total_profits_usd,
          trades_executed: metrics.trades_executed,

          popular_tokens: metrics.popular_tokens_json || [],
          recent_activity: recent_activity,
          top_performers: metrics.top_performers_json || [],

          last_updated: metrics.created_at.iso8601
        }
      end

      private

      def calculate_percentage_change(current, previous)
        return nil unless previous && previous > 0
        return nil if current == 0

        ((current - previous).to_f / previous * 100).round(1)
      end
    end
  end
end