# frozen_string_literal: true

module Billetto
  Error = Class.new(StandardError)

  # No credentials configured.
  ConfigurationError = Class.new(Error)

  # Billetto rejected the credentials.
  AuthenticationFailed = Class.new(Error)

  # Anything else that stopped us getting a usable response: timeouts,
  # connection resets, 4xx and 5xx responses, unparseable bodies.
  RequestFailed = Class.new(Error)

  # A single event in the response did not carry the fields we require.
  InvalidPayload = Class.new(Error)
end
