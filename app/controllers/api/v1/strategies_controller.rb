module Api
  module V1
    class StrategiesController < Api::BaseController
      wrap_parameters false
      before_action :require_quick_auth!, only: [:create]
      CONFIRMATION_DELAY = 5.seconds
      
      # GET /api/v1/strategies
      def index
        @strategies = Strategy.order(created_at: :desc).limit(100)
        
        formatted_strategies = @strategies.map do |strategy|
          {
            id: strategy.id.to_s,
            nft_token_id: strategy.nft_token_id.to_s,
            #compressed_strategy: strategy.compressed_strategy,
            #user_friendly_strategy: strategy.user_friendly_strategy,
            #creator_address: strategy.creator_address,
            #created_at: strategy.created_at.iso8601
          }
        end
        
        render json: formatted_strategies
      end
      
      # GET /api/v1/strategies/:id
      def show
        strategy = Strategy.find_by(nft_token_id: params[:id])
        
        unless strategy
          render json: {
            error: "Strategy not found",
            code: "STRATEGY_NOT_FOUND"
          }, status: :not_found and return
        end
        
        render json: {
          id: strategy.id.to_s,
          strategy_id: strategy.nft_token_id.to_s,
          owner_address: strategy.owner_address,
          compressed_strategy: strategy.strategy_json,
          user_friendly_strategy: strategy.longform.to_json,
          created_at: strategy.created_at.iso8601
          #user_friendly_strategy: strategy.user_friendly_strategy,
          #creator_address: strategy.creator_address
        }
      end
      
      # POST /api/v1/strategies/validate
      def validate
        puts "********** #{params[:strategy].to_s} **********"
        result = StrategiesValidate.call(params[:strategy])
        render json: result, status: :ok

        #result =       {
        #  valid: true,
        #  compressed: params[:strategy]
        #}
        #render json: result, status: :ok
      end

      def validate2
        user_strategy = params[:strategy].to_s.strip
        
        if user_strategy.blank?
          render json: {
            error: "Missing required parameter: strategy",
            code: "MISSING_STRATEGY"
          }, status: :bad_request and return
        end
        
        #result = StrategyValidationService.new(user_strategy).validate
        
        #if result[:valid]
        #  render json: {
        #    valid: true,
        #    compressed: result[:compressed]
        #  }, status: :ok
        #else
        #  render json: {
        #    valid: false,
        #    error: result[:error],
        #    code: "INVALID_STRATEGY"
        #  }, status: :unprocessable_entity
        #end

        render json: {
          valid: true,
          #compressed: result[:compressed]
        }, status: :ok
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