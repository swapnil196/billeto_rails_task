# frozen_string_literal: true

module Clerk
  class SessionVerifier
    ALGORITHM = "RS256"
    DEFAULT_LEEWAY = 5

    def initialize(key_source:, authorized_parties: [], leeway: DEFAULT_LEEWAY)
      @key_source = key_source
      @authorized_parties = Array(authorized_parties).compact_blank
      @leeway = leeway
    end

    def verify(token)
      raise VerificationFailed, "no session token" if token.blank?

      claims, = JWT.decode(
        token,
        nil,
        true,
        algorithms: [ ALGORITHM ],
        jwks: @key_source.to_jwk_loader,
        verify_expiration: true,
        verify_not_before: true,
        leeway: @leeway
      )

      verify_authorized_party!(claims)
      build_session(claims)
    rescue JWT::DecodeError => exception
      raise VerificationFailed, exception.message
    end

    private

    def verify_authorized_party!(claims)
      return if @authorized_parties.empty?

      azp = claims["azp"]
      return if azp.present? && @authorized_parties.include?(azp)

      raise VerificationFailed, "token was issued for another party"
    end

    def build_session(claims)
      user_id = claims["sub"]
      raise VerificationFailed, "token carried no subject" if user_id.blank?

      Session.new(
        user_id: user_id,
        claims: claims,
        expires_at: claims["exp"] && Time.zone.at(claims["exp"])
      )
    end
  end
end
