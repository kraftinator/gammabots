include ActionView::Helpers::DateHelper

module Api
  module V1
    class BotsController < Api::BaseController
      before_action :require_quick_auth!
      STRATEGY_NFT_CONTRACT_ADDRESS = "abcdef123456"
      
      def index
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        status = params[:status]          
        if status == 'retired'
          @bots = Bot.inactive
              .joins(:trades)
              .where(trades: { status: 'completed' })
              .order(updated_at: :desc)
              .distinct                      
              .limit(100)
              .to_a
        else
          @bots = current_user.bots.active.default_bots + current_user.bots.inactive.unfunded
        end

        formatted_bots = @bots.map do |bot|
          if bot.unfunded?
            {
              bot_id: bot.id.to_s,
              token_symbol: bot.token_pair.base_token.symbol,
              strategy_id: bot.strategy.nft_token_id.to_s,
              moving_average: bot.moving_avg_minutes,
              tokens: 0,
              eth: 0,
              init: bot.initial_buy_amount,
              value: 0,
              profit_percent: 0,
              cycles: 0,
              trades: 0,
              is_active: false,
              status: 'unfunded',
              last_action: "#{time_ago_in_words(bot.updated_at)} ago"
            }
          else
            {
              bot_id: bot.id.to_s,
              token_symbol: bot.token_pair.base_token.symbol,
              strategy_id: bot.strategy.nft_token_id.to_s,
              moving_average: bot.moving_avg_minutes,
              tokens: bot.current_cycle.trades.any? ? bot.current_cycle.base_token_amount.round(6) : 0,
              eth: bot.current_cycle.quote_token_amount.round(6),
              init: bot.initial_buy_amount,
              value: bot.current_value,
              profit_percent: bot.profit_percentage(include_profit_withdrawals: true),
              cycles: bot.bot_cycles.count,
              trades: bot.buy_count + bot.sell_count,
              is_active: bot.active,
              status: bot.status,
              last_action: "#{time_ago_in_words(bot.last_action_at)} ago"
            }
          end
        end
        
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

      def create
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        puts "params = #{params}"
        puts "current_user.id = #{current_user.id}"

        moving_avg_minutes = validate_moving_average_param!
        amount = validate_eth_amount_param!
        strategy = validate_strategy_param!

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

        bot_attrs = {
          chain: chain,
          strategy: strategy,
          moving_avg_minutes: moving_avg_minutes,
          user: current_user,
          token_pair: token_pair,
          initial_buy_amount: amount,
          active: false
        }

        bot = Bot.create!(bot_attrs)

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

      private

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
          render json: {
            error: "Missing required parameter: strategy_id",
            code:  "MISSING_STRATEGY_ID"
          }, status: :bad_request and return
        end

        # Only allow integers
        unless raw.match?(/\A\d+\z/)
          render json: {
            error: "Invalid strategy_id. Must be an integer.",
            code:  "INVALID_STRATEGY_ID"
          }, status: :bad_request and return
        end

        strategy = Strategy.find_by(contract_address: STRATEGY_NFT_CONTRACT_ADDRESS, nft_token_id: raw.to_i)

        unless strategy
          render json: {
            error: "Strategy not found",
            code:  "STRATEGY_NOT_FOUND"
          }, status: :not_found and return
        end

        strategy
      end

      def validate_eth_amount_param!
        raw = params[:eth_amount].to_s.strip

        if raw.blank?
          render json: {
            error: "Missing required parameter: eth_amount",
            code:  "MISSING_ETH_AMOUNT"
          }, status: :bad_request and return
        end

        # Allow integers or decimals, no letters, no weird symbols
        unless raw.match?(/\A\d+(\.\d+)?\z/)
          render json: {
            error: "Invalid eth_amount. Must be a numeric value.",
            code:  "INVALID_ETH_AMOUNT"
          }, status: :bad_request and return
        end

        BigDecimal(raw)
      end

      def validate_moving_average_param!
        raw = params[:moving_average].to_s.strip

        if raw.blank?
          render json: {
            error: "Missing required parameter: moving_average",
            code:  "MISSING_MOVING_AVERAGE"
          }, status: :bad_request and return
        end

        unless raw.match?(/\A\d+\z/)
          render json: {
            error: "Invalid moving_average. Must be an integer.",
            code:  "INVALID_MOVING_AVERAGE"
          }, status: :bad_request and return
        end

        raw.to_i
      end
    end
  end
end