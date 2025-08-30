# app/services/quick_auth_verifier.rb
require 'jwt'; require 'faraday'; require 'json'

class QuickAuthVerifier
  ISSUER   = Rails.application.credentials.fcast_auth_iss || 'https://auth.farcaster.xyz'
  AUDIENCE = ENV['FCAST_MINIAPP_AUD'] || Rails.application.credentials.fcast_miniapp_aud
  JWKS_URI = "#{ISSUER}/.well-known/jwks.json"

  class << self
    def verify!(token)
      if AUDIENCE.nil? || AUDIENCE.strip.empty?
        raise JWT::InvalidAudError, 'FCAST_MINIAPP_AUD is not configured'
      end

      header = JWT.decode(token, nil, false).last
      kid = header['kid'] or raise JWT::DecodeError, 'missing kid'

      jwk = jwks['keys'].find { |k| k['kid'] == kid } or raise JWT::DecodeError, 'unknown kid'
      key = JWT::JWK.import(jwk).public_key

      payload, = JWT.decode(
        token, key, true,
        algorithm: 'RS256',
        iss: ISSUER, verify_iss: true,
        aud: AUDIENCE, verify_aud: true
      )
      payload
    end

    def jwks
      if @jwks.nil? || @fetched_at.nil? || (Time.now - @fetched_at) > 300
        resp = Faraday.get(JWKS_URI); raise "JWKS #{resp.status}" unless resp.success?
        @jwks = JSON.parse(resp.body); @fetched_at = Time.now
      end
      @jwks
    end
  end
end