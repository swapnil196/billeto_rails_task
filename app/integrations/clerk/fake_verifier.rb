# frozen_string_literal: true

module Clerk
  # Stands in for SessionVerifier in tests and in development without keys.
  class FakeVerifier
    PREFIX = "user_"

    def verify(token)
      raise VerificationFailed, "no session token" if token.blank?
      raise VerificationFailed, "expired" if token.to_s == "expired"

      user_id = token.to_s
      user_id = "#{PREFIX}#{user_id}" unless user_id.start_with?(PREFIX)

      Session.new(user_id: user_id, claims: { "sub" => user_id }, expires_at: 1.hour.from_now)
    end
  end
end
