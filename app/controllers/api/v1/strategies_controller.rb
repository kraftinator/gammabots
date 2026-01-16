module Api
  module V1
    class StrategiesController < Api::BaseController
      wrap_parameters false
      before_action :require_quick_auth!, only: [:create, :mint_details]
      

      CONFIRMATION_DELAY = 5.seconds
      STRATEGY_NFT_CONTRACT_ADDRESS = ENV["STRATEGY_NFT_CONTRACT_ADDRESS"]
=begin
      # GET /api/v1/strategies
      def index
        #strategies = Strategy.order(created_at: :desc).where.not(nft_token_id: [nil, ""]).limit(200)
        strategies = Strategy.canonical.order(created_at: :desc).limit(200)
        strategy_ids = strategies.pluck(:id)

        bots = Bot
          .joins(:bot_cycles, :trades)
          .where(strategy_id: strategy_ids)
          .includes(:trades, :profit_withdrawals)
          .distinct

        bots_counts = bots.group_by(&:strategy_id).transform_values(&:size)

        sums   = Hash.new(0.0)
        counts = Hash.new(0)

        bots.each do |bot|
          pct = bot.profit_percentage(include_profit_withdrawals: true).to_f
          sums[bot.strategy_id] += pct
          counts[bot.strategy_id] += 1
        end

        render json: strategies.map { |s|
          creator_user = s.creator
          c = counts[s.id]
          avg = c > 0 ? (sums[s.id] / c) : nil

          {
            strategy_id: s.nft_token_id.to_s,
            creator_address: s.creator_address,
            creator_handle: creator_user&.farcaster_username,
            created_at: s.created_at.iso8601,
            bots_count: bots_counts[s.id] || 0,
            performance_pct: avg
          }
        }
      end
=end

# GET /api/v1/strategies
def index
  strategies = Strategy.canonical.order(created_at: :desc).limit(200)
  strategy_ids = strategies.pluck(:id)

  # Popularity: all bots using the strategy
  bots_counts = Bot.where(strategy_id: strategy_ids).group(:strategy_id).count

  # Performance: only bots that have trades (so profit_percentage won't error)
  perf_bots = Bot.joins(:trades)
                 .where(strategy_id: strategy_ids)
                 .includes(:trades, :profit_withdrawals)
                 .distinct

  sums   = Hash.new(0.0)
  counts = Hash.new(0)

  perf_bots.each do |bot|
    pct = bot.profit_percentage(include_profit_withdrawals: true).to_f
    sums[bot.strategy_id] += pct
    counts[bot.strategy_id] += 1
  end

  render json: strategies.map { |s|
    creator_user = s.creator
    c = counts[s.id]
    avg = c > 0 ? (sums[s.id] / c) : nil

    {
      strategy_id: s.nft_token_id.to_s,
      creator_address: s.creator_address,
      creator_handle: creator_user&.farcaster_username,
      created_at: s.created_at.iso8601,
      bots_count: bots_counts[s.id] || 0,
      performance_pct: avg
    }
  }
end

      # GET /api/v1/strategies/:id
      def show
        #strategy = Strategy.find_by(nft_token_id: params[:id])
        strategy = Strategy.find_canonical(params[:id].to_s)
        
        unless strategy
          render json: { error: "Strategy not found", code: "STRATEGY_NOT_FOUND" }, status: :not_found
          return
        end

        creator_user = strategy.creator
        
        render json: {
          id: strategy.id.to_s,
          strategy_id: strategy.nft_token_id.to_s,
          creator_address: strategy.creator_address,
          creator_handle: creator_user&.farcaster_username,
          owner_address: strategy.owner_address,
          compressed_strategy: strategy.strategy_json,
          user_friendly_strategy: strategy.longform.to_json,
          mint_status: strategy.mint_status,
          status: strategy.status,
          created_at: strategy.created_at.iso8601
        }
      end

      def stats
        strategy = Strategy.find_canonical(params[:id].to_s)

        unless strategy
          render json: { error: "Strategy not found", code: "STRATEGY_NOT_FOUND" }, status: :not_found and return
        end

        creator_user = strategy.creator

        bots = Bot
          .joins(:bot_cycles, :trades)
          .where(strategy_id: strategy.id)
          .includes(:trades, :profit_withdrawals, :user)
          .distinct

        bots_count = bots.size

        sum = 0.0
        n   = 0

        top_bot_id  = nil
        top_bot_pct = nil

        bots.each do |bot|
          v = bot.profit_percentage(include_profit_withdrawals: true)
          next if v.nil?

          f = v.to_f
          next unless f.finite?

          sum += f
          n += 1

          if top_bot_pct.nil? || f > top_bot_pct
            top_bot_pct = f
            top_bot_id  = bot.id
          end
        end

        performance_pct = n.zero? ? nil : (sum / n)

        top_bot = top_bot_id ? bots.find { |b| b.id == top_bot_id } : nil

        render json: {
          id: strategy.id.to_s,
          strategy_id: strategy.nft_token_id.to_s,
          creator_address: strategy.creator_address,
          creator_handle: creator_user&.farcaster_username,
          owner_address: strategy.owner_address,
          compressed_strategy: strategy.strategy_json,
          user_friendly_strategy: strategy.longform.to_json,
          mint_status: strategy.mint_status,
          status: strategy.status,
          created_at: strategy.created_at.iso8601,
          bots_count: bots_count,
          performance_pct: performance_pct,
          top_bot: top_bot && {
            bot_id: top_bot.id.to_s,
            bot_display_name: top_bot.display_name,
            token_symbol:  top_bot.token_pair.base_token.symbol,
            owner_handle: top_bot.user&.farcaster_username,
            profit_pct: top_bot_pct
          },
        }
      end

      #  GET /api/v1/strategies/mint_details
      def mint_details
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        chain = Chain.find_by(name: 'base_mainnet')
        wallet_address = params[:wallet_address].to_s
        provider_url = ProviderUrlService.get_provider_url(chain.name)

        result = EthersService.get_mint_fee_details(
          wallet_address,
          STRATEGY_NFT_CONTRACT_ADDRESS,
          provider_url
        )

        render json: result
      end
      
      # POST /api/v1/strategies/validate
      def validate
        result = StrategiesValidate.call(params[:strategy])
        render json: result, status: :ok
      end
     
      # POST /api/v1/strategies
      def create
        unless current_user
          return unauthorized!('User not found. Please ensure you have a valid Farcaster account.')
        end

        tx_hash = params[:mint_tx_hash].to_s.strip
        if tx_hash.blank?
          return render json: { error: "mint_tx_hash is required" }, status: :unprocessable_entity
        end

        chain = Chain.find_by(name: 'base_mainnet')
        strategy = Strategy.create!(chain: chain, mint_tx_hash: tx_hash)

        Strategies::ConfirmMintJob.set(wait: CONFIRMATION_DELAY).perform_later(strategy.id)

        render json: {
          id: strategy.id,
          mint_tx_hash: strategy.mint_tx_hash,
          mint_status: strategy.mint_status
        }, status: :accepted
      end

      # GET /api/v1/strategies/:id/mint_status
      def mint_status
        strategy = Strategy.find(params[:id])
        render json: {
          id: strategy.id.to_s,
          mint_status: strategy.mint_status,
          nft_token_id: strategy.nft_token_id&.to_s,
          status: strategy.status
        }
      end
      
      private
      
      def validate_nft_token_id_param!
        raw = params[:nft_token_id].to_s.strip
        
        if raw.blank?
          render json: {
            error: "Missing required parameter: nft_token_id",
            code: "MISSING_NFT_TOKEN_ID"
          }, status: :bad_request and return
        end
        
        unless raw.match?(/\A\d+\z/)
          render json: {
            error: "Invalid nft_token_id. Must be an integer.",
            code: "INVALID_NFT_TOKEN_ID"
          }, status: :bad_request and return
        end
        
        raw.to_i
      end
      
      def validate_compressed_strategy_param!
        raw = params[:compressed_strategy].to_s.strip
        
        if raw.blank?
          render json: {
            error: "Missing required parameter: compressed_strategy",
            code: "MISSING_COMPRESSED_STRATEGY"
          }, status: :bad_request and return
        end
        
        # Check size limit (5KB)
        if raw.bytesize > 5000
          render json: {
            error: "Strategy exceeds 5KB limit",
            code: "STRATEGY_TOO_LARGE"
          }, status: :bad_request and return
        end
        
        raw
      end
    end
  end
end