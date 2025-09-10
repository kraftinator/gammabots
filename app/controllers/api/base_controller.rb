module Api
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token
    # CORS must run first so preflight succeeds
    before_action :set_cors_headers
    before_action :handle_options_request
    # Service-level gate runs after CORS/preflight
    before_action :require_api_key!

    protected

    # ---------- API Key ----------
    def require_api_key!
      return if request.options? # never block CORS preflight

      # Prefer header; keep param for compatibility with older callers
      key = request.headers['X-API-Key'].presence || params[:apikey]
      unauthorized!('invalid api key') and return unless secure_compare_key(key)
    end

    def secure_compare_key(key)
      expected = Rails.application.credentials.api_key
      expected.present? && key.present? &&
        ActiveSupport::SecurityUtils.secure_compare(key.to_s, expected.to_s)
    end

    # ---------- Quick Auth (JWT) ----------
    # Call this in child controllers when you need a verified Farcaster user
    def require_quick_auth!
      token = bearer_token or return unauthorized!('missing bearer token')
      payload = QuickAuthVerifier.verify!(token)
      @current_fid = payload['sub']   # Farcaster FID
    rescue => e
      Rails.logger.warn("QuickAuth failed: #{e.class}: #{e.message}")
      unauthorized!('invalid token')
    end

    def current_fid
      @current_fid
    end

    def current_user
      return nil unless current_fid
      @current_user ||= User.find_by(farcaster_id: current_fid)
    end

    def bearer_token
      auth = request.authorization
      auth&.start_with?('Bearer ') ? auth.split(' ', 2).last : nil
    end

    # ---------- Helpers ----------
    def unauthorized!(msg = 'unauthorized')
      render json: { error: msg }, status: :unauthorized
    end

    def set_cors_headers
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
      # Allow the headers your client/proxy actually sends
      response.headers['Access-Control-Allow-Headers'] =
        'Authorization, Content-Type, X-API-Key, Accept'
      response.headers['Access-Control-Allow-Credentials'] = 'false'
    end

    def handle_options_request
      head :ok and return if request.method == 'OPTIONS'
    end
  end
end
