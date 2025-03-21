module Api
  class BaseController < ApplicationController
    # Skip CSRF protection for API endpoints
    skip_before_action :verify_authenticity_token
    before_action :authenticate_api_key
    
    protected
    
    def authenticate_api_key
      api_key = params[:apikey]
      
      unless api_key.present? && valid_api_key?(api_key)
        render json: { error: 'Unauthorized access. Invalid or missing API key.' }, status: :unauthorized
        return
      end
    end
    
    def valid_api_key?(key)
      Rails.application.credentials.api_key == key
    end
  end
end