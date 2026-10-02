# frozen_string_literal: true

module Clerk
  Error = Class.new(StandardError)

  # No verifier configured.
  ConfigurationError = Class.new(Error)

  # The token was absent, malformed, expired, or not signed by Clerk.
  VerificationFailed = Class.new(Error)

  # Everything the application is allowed to know about who is asking.
  Session = Struct.new(:user_id, :claims, :expires_at, keyword_init: true) do
    def to_s
      user_id.to_s
    end
  end
end
