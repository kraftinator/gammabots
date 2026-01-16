include ActionView::Helpers::DateHelper

module Api
  module V1
    class BotsController < Api::BaseController
      after_action :log_response_for_debugging
      before_action :require_quick_auth!
      #STRATEGY_NFT_CONTRACT_ADDRESS = "abcdef123456"
      STRATEGY_NFT_CONTRACT_ADDRESS = ENV['STRATEGY_NFT_CONTRACT_ADDRESS']
      
      def index
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        status = params[:status]          

        if status == 'inactive'
          @bots = current_user.bots
            .inactive
            .default_bots
            .visible
            .where(status: ["active", "inactive", "funding_failed"])
            .order(Arel.sql("COALESCE(deactivated_at, updated_at) DESC"))
            .limit(100)
        else
          @bots = current_user.bots.visible.active.default_bots + current_user.bots.visible.inactive.unfunded
        end

        formatted_bots = @bots.map { |bot| bot_payload(bot) }

        render json: formatted_bots
      end

      # POST /api/v1/bots/:id/fund
      def fund
        bot = current_user.bots.find(params[:id])
        tx_hash = params[:tx_hash]

        # For now, just log / stub
        Rails.logger.info "Attach tx #{tx_hash} to bot #{bot.id}"
        bot.update!(funding_tx_hash: tx_hash.to_s.strip.downcase)
        FundingManager.confirm_funding!(bot)

        render json: { ok: true, bot_id: bot.id, tx_hash: tx_hash }
      end

      def deactivate
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        bot = current_user.bots.find(params[:id])

        if bot.initial_buy_made?
          return render json: {
            error: "Bot cannot be force-deactivated after a buy has been made",
            code: "INVALID_DEACTIVATION_STATE"
          }, status: :unprocessable_entity
        end

        bot.forced_deactivate
        
        bot.reload
        render json: { bot_id: bot.id, is_active: bot.active, status: bot.status }, status: :ok
      end

      def liquidate
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        bot = current_user.bots.find(params[:id])
        trade = bot.liquidate
        
        if trade
          bot.reload
          render json: { bot_id: bot.id, status: bot.status, liquidation_tx_hash: trade.tx_hash }, status: :ok
        else
          render json: { error: "Failed to liquidate", code: "LIQUIDATION_ERROR" }, status: :bad_request
        end
      end

      def create
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        moving_avg_minutes_result = validate_moving_average_param!
        unless moving_avg_minutes_result[:success]
          render json: {
            error: moving_avg_minutes_result[:message][:error],
            code:  moving_avg_minutes_result[:message][:code]
          }, status: moving_avg_minutes_result[:message][:status] and return
        end
        moving_avg_minutes = moving_avg_minutes_result[:moving_avg_minutes]

        amount_result = validate_eth_amount_param!
        unless amount_result[:success]
          render json: {
            error: amount_result[:message][:error],
            code:  amount_result[:message][:code]
          }, status: amount_result[:message][:status] and return
        end
        amount = amount_result[:amount]
      
        strategy_result = validate_strategy_param!
        unless strategy_result[:success]
          render json: {
            error: strategy_result[:message][:error],
            code:  strategy_result[:message][:code]
          }, status: strategy_result[:message][:status] and return
        end
        strategy = strategy_result[:strategy]

        token_param = params[:token_address].to_s.strip
        if token_param.match?(/\A0x[a-fA-F0-9]{40}\z/)
          token_contract_address = token_param.downcase
        else
          render json: {
            error: "Invalid token address format.",
            code:  "INVALID_TOKEN_ADDRESS"
          }, status: :bad_request and return
        end

        chain = Chain.find_by(name: 'base_mainnet')
        token_pair = CreateTokenPairService.call(
          token_address: token_contract_address,
          chain: chain
        )

        unless token_pair          
          render json: {
            error: "Invalid token",
            code:  "INVALID_TOKEN"
          }, status: :bad_request and return
        end

        bot = nil

        begin
          Bot.transaction do
            last = Bot.where(token_pair_id: token_pair.id)
                      .where.not(token_ordinal: nil)
                      .order(token_ordinal: :desc)
                      .first

            next_ordinal = (last&.token_ordinal || 0) + 1

            bot_attrs = {
              chain: chain,
              strategy: strategy,
              moving_avg_minutes: moving_avg_minutes,
              user: current_user,
              token_pair: token_pair,
              initial_buy_amount: amount,
              active: false,
              token_ordinal: next_ordinal
            }

            bot = Bot.create!(bot_attrs)
          end
        rescue ActiveRecord::RecordNotUnique
          retry
        end

        if bot
          # build payment hash
          wallet = current_user.wallet_for_chain(chain)
          provider_url = ProviderUrlService.get_provider_url(chain.name)

          reserve_info = GasReserveService.needed_for(
            user: current_user,
            chain: chain,
            bot_amount_eth: amount,
            provider_url: provider_url
          )

          bot.update!(
            funding_expected_amount: wei_to_eth(reserve_info[:total_required_wei])
          )

          payment = {
            to: wallet.address,
            #value: eth_to_wei(bot.initial_buy_amount),
            value: reserve_info[:total_required_wei],
            chainId: chain.native_chain_id
          }

          gas = {
            target_wei:       reserve_info[:target_wei],
            current_balance:  reserve_info[:current_balance_wei],
            needed_topup_wei: reserve_info[:needed_topup_wei]
          }

          render json: { 
            bot_id: bot.id.to_s, 
            status: bot.status,
            payment: payment,
            gas: gas,
          }, status: :ok and return
        else
          render json: {
            error: "Failed to create bot",
            code:  "BOT_CREATE_ERROR"
          }, status: :bad_request and return
        end
      end

      def metrics
        bot = current_user.bots.find(params[:id])

        metrics = bot.strategy_variables(use_cached_price: true)

        # Remove internal fields
        metrics.except!("bot", :bot, "provider_url", :provider_url, "ndp", :ndp, "nd2", :nd2, "bep", :bep)

        # normalize time-based fields for UI
        %w[lta lba crt].each do |short_key|
          val = metrics[short_key] || metrics[short_key.to_sym]
          next unless val.is_a?(Time) || val.is_a?(ActiveSupport::TimeWithZone)

          #minutes = ((Time.current - val) / 60.0).round(1)
          minutes = ((Time.current - val) / 60.0).floor
          metrics[short_key] = minutes
        end

        # Transform keys from 3-char codes → full field names
        mapped_metrics = map_metric_keys(metrics)

        render json: { success: true, metrics: mapped_metrics }
      rescue StandardError => e
        Rails.logger.error("[BotMetrics] #{e.class}: #{e.message}")
        render json: { success: false, error: "Unable to load metrics" }, status: :unprocessable_entity
      end

      def trades
        bot = current_user.bots.find(params[:id])

        trades = bot.trades
                    .includes(:bot_cycle)   # eager load so N+1 queries don’t happen
                    .order(executed_at: :asc)
                    .limit(params[:limit] || 100)

        render json: {
          success: true,
          trades: trades.map { |t|
            {
              id: t.id,
              side: t.trade_type,
              amount_in: t.amount_in,
              amount_out: t.amount_out,
              price: t.price,
              tx_hash: t.tx_hash,
              status: t.status,
              executed_at: t.executed_at,
              cycle: t.bot_cycle&.ordinal,
              strategy: t.metrics["strategy"],
              step: t.metrics["step"]
            }
          }
        }
      end

      def update
        bot = current_user.bots.find(params[:id])

        moving_avg_minutes_result = validate_moving_average_param!
        unless moving_avg_minutes_result[:success]
          render json: {
            error: moving_avg_minutes_result[:message][:error],
            code:  moving_avg_minutes_result[:message][:code]
          }, status: moving_avg_minutes_result[:message][:status] and return
        end
        moving_avg_minutes = moving_avg_minutes_result[:moving_avg_minutes]

        strategy_result = validate_strategy_param!
        unless strategy_result[:success]
          render json: {
            error: strategy_result[:message][:error],
            code:  strategy_result[:message][:code]
          }, status: strategy_result[:message][:status] and return
        end
        strategy = strategy_result[:strategy]

        bot_attrs = {
          strategy: strategy,
          moving_avg_minutes: moving_avg_minutes
        }

        if bot.update(bot_attrs)
          render json: { success: true, bot: bot_payload(bot) }
        else
          render json: { success: false, errors: bot.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def map_metric_keys(hash)
        hash.each_with_object({}) do |(key, value), out|
          readable = Gammascript::Constants::VALID_FIELDS[key.to_s] || key
          out[readable] = value
        end
      end

      def eth_to_wei(eth_decimal)
        # eth_decimal is a BigDecimal representing ETH (e.g., 0.25)
        # multiply by 10^18 and cast to integer (floor) — then stringify
        (BigDecimal(eth_decimal.to_s) * BigDecimal('1000000000000000000')).to_i.to_s
      end

      def wei_to_eth(wei)
        BigDecimal(wei.to_s) / (10**18)
      end

      def validate_strategy_param!
        raw = params[:strategy_id].to_s.strip

        if raw.blank?
          return { 
            success: false, 
            message: {
              error: "Missing strategy",
              code:  "MISSING_STRATEGY",
              status: :bad_request
            }
          }
        end

        # Only allow integers
        unless raw.match?(/\A\d+\z/)
          return { 
            success: false, 
            message: {
              error: "Invalid Strategy. Must be an integer.",
              code:  "MISSING_STRATEGY",
              status: :bad_request
            }
          }
        end

        #strategy = Strategy.find_by(contract_address: STRATEGY_NFT_CONTRACT_ADDRESS, nft_token_id: raw.to_i)
        strategy = Strategy.find_canonical(raw.to_i)

        unless strategy
          return { 
            success: false, 
            message: {
              error: "Strategy not found",
              code:  "STRATEGY_NOT_FOUND",
              status: :not_found
            }
          }
        end

        { success: true, strategy: strategy }
      end

      def validate_eth_amount_param!
        raw = params[:eth_amount].to_s.strip

        if raw.blank?
          return { 
            success: false, 
            message: {
              error: "Missing ETH amount",
              code:  "MISSING_ETH_AMOUNT",
              status: :bad_request
            }
          }
        end

        # Allow integers or decimals, no letters, no weird symbols
        unless raw.match?(/\A\d+(\.\d+)?\z/)
          return { 
            success: false, 
            message: {
              error: "ETH amount must be numeric",
              code:  "INVALID_ETH_AMOUNT",
              status: :bad_request
            }
          }          
        end

         { success: true, amount: BigDecimal(raw) }
      end

      def log_response_for_debugging
        Rails.logger.info "[BOTS] RESPONSE status=#{response.status} body=#{response.body.inspect}"
      end

      def validate_moving_average_param!
        raw = params[:moving_average].to_s.strip

        if raw.blank?
          return { 
            success: false, 
            message: {
              error: "Missing Moving Average",
              code:  "INVALID_MOVING_AVERAGE",
              status: :bad_request
            }
          }
        end

        unless raw.match?(/\A\d+\z/)
          return { 
            success: false, 
            message: {
              error: "Moving Average must be numeric",
              code:  "INVALID_MOVING_AVERAGE",
              status: :bad_request
            }
          }
        end

        moving_average = raw.to_i
        if moving_average < 1
          return { 
            success: false, 
            message: {
              error: "Moving Average must be greater than 0",
              code:  "INVALID_MOVING_AVERAGE",
              status: :bad_request
            }
          }
        end

        if moving_average > 60
          return { 
            success: false, 
            message: {
              error: "Moving Average must be less than 61",
              code:  "INVALID_MOVING_AVERAGE",
              status: :bad_request
            }
          }
        end

        { success: true, moving_avg_minutes: moving_average }
      end

      def bot_status_label(bot)
        # Unfunded is its own special thing
        return "unfunded" if bot.unfunded?

        if bot.active
          bot.status
        elsif %w[active inactive].include?(bot.status)
          # Manually stopped vs completed
          bot.completed_trade_count > 0 ? "completed" : "stopped"
        else
          # Preserve special states like "funding_failed"
          bot.status
        end
      end

      def bot_payload(bot)
        base = {
          bot_id:         bot.id.to_s,
          display_name:   bot.display_name,
          bot_owner_id:   bot.user.id.to_s,
          token_symbol:   bot.token_pair.base_token.symbol,
          token_name:     bot.token_pair.base_token.name,
          token_address:  bot.token_pair.base_token.contract_address,
          strategy_id:    bot.strategy.nft_token_id.to_s,
          moving_average: bot.moving_avg_minutes,
          init:           bot.initial_buy_amount,
          cycles:         bot.bot_cycles.count,
          trades:         bot.buy_count + bot.sell_count,
          is_active:      bot.active,
          status:         bot_status_label(bot),
          trade_mode:     bot.current_cycle ? bot.trade_mode : "buy",
          last_action:    bot.last_action_at
        }

        # Unfunded bots
        return base.merge(
          tokens:         0,
          eth:            0,
          value:          0,
          profit_percent: 0
        ) if bot.unfunded?

        cycle = bot.current_cycle

        # Safety: cycle can be nil (e.g. funding_failed)
        return base.merge(
          tokens:         0,
          eth:            0,
          value:          0,
          profit_percent: 0
        ) unless cycle

        base.merge(
          tokens:         cycle.trades.any? ? cycle.base_token_amount.round(6) : 0,
          eth:            cycle.quote_token_amount.round(6),
          value:          bot.display_value, # your “final vs current” logic lives in the model
          profit_percent: bot.profit_percentage(include_profit_withdrawals: true)
        )
      end

    end
  end
end