# app/controllers/api/v1/dashboard_metrics_controller.rb
include ActionView::Helpers::DateHelper

module Api
  module V1
    class DashboardMetricsController < Api::BaseController
      before_action :require_quick_auth!

      def index
        metrics = DashboardMetric.latest
        metrics_24h_ago = DashboardMetric.where('created_at <= ?', 24.hours.ago)
                                         .order(created_at: :desc)
                                         .first
        
        if metrics.nil?
          render json: { error: "No metrics available" }, status: 404
          return
        end

        @active_bots = Bot.active.default_bots
        @eth_price_usd = TokenPriceService.get_eth_price_in_usd(@active_bots.first&.chain)

        render json: {
          active_bots: metrics.active_bots,
          user_bot_count: current_user.bots.active.default_bots.count,
          active_bots_change_24h: calculate_percentage_change(metrics.active_bots, metrics_24h_ago&.active_bots),
          tvl: metrics.tvl_usd,
          tvl_change_24h: calculate_percentage_change(metrics.tvl_cents, metrics_24h_ago&.tvl_cents),
          volume_24h: metrics.volume_24h_usd,
          volume_24h_change_24h: calculate_percentage_change(metrics.volume_24h_cents, metrics_24h_ago&.volume_24h_cents),
          strategies: metrics.strategies_count,
          total_profits: metrics.total_profits_usd,
          trades_executed: metrics.trades_executed,
          popular_tokens: calculate_popular_tokens,
          recent_activity: calculate_recent_activity,
          top_performers: calculate_top_performers,
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
          
          # Only calculate performance for sell trades
          performance_pct = if trade.sell?
            cycle = trade.bot_cycle
            (cycle.profit_fraction(include_profit_withdrawals: true) * 100).round(1)
          else
            nil # No percentage for buy trades
          end
          
          {
            farcaster_username: user.farcaster_username,
            farcaster_avatar_url: user.farcaster_avatar_url,
            action: trade.trade_type.capitalize,
            amount: token_amount.round(0),
            token_symbol: trade.bot.token_pair.base_token.symbol,
            strategy_id: trade.bot.strategy.nft_token_id,
            bot_id: trade.bot.id,
            performance_pct: performance_pct, # nil for buys, percentage for sells
            time_ago: time_ago_in_words(trade.executed_at)
          }
        end
      end

      def calculate_top_performers
        # Get sell trades from last 7 days
        recent_sell_trades = Trade.joins(:bot)
                                  .where(bot: Bot.default_bots)
                                  .where(status: 'completed', trade_type: 'sell')
                                  .where('executed_at >= ?', 7.days.ago)

        # Get their associated bot_cycles
        cycle_ids = recent_sell_trades.pluck(:bot_cycle_id).uniq
        cycles = BotCycle.where(id: cycle_ids)

        # Filter to profitable cycles and sort by performance
        profitable_cycles = cycles.select do |cycle|
          cycle.profit_fraction(include_profit_withdrawals: true) > 0
        end

        top_performers = profitable_cycles.sort_by do |cycle|
          -cycle.profit_fraction(include_profit_withdrawals: true)
        end.first(3)

        # Format for API response
        top_performers.map do |cycle|
          {
            bot_id: cycle.bot.id,
            username: cycle.bot.user.farcaster_username,
            strategy_id: cycle.bot.strategy.nft_token_id,
            token_symbol: cycle.bot.token_pair.base_token.symbol,
            performance: (cycle.profit_fraction(include_profit_withdrawals: true) * 100).round(1)
          }
        end
      end

      def calculate_percentage_change(current, previous)
        return nil unless previous && previous > 0
        ((current - previous).to_f / previous * 100).round(1)
      end
    end
  end
end