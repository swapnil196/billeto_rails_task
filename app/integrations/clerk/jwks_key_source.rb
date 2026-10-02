# frozen_string_literal: true

module Clerk
  class JwksKeySource
    DEFAULT_TTL = 1.hour

    def initialize(jwks_url:, http: HttpClient.new, ttl: DEFAULT_TTL, clock: -> { Time.current })
      raise ConfigurationError, "Clerk JWKS url is missing" if jwks_url.blank?

      @jwks_url = jwks_url
      @http = http
      @ttl = ttl
      @clock = clock
      @mutex = Mutex.new
    end

    def to_jwk_loader
      lambda do |options|
        fetch(force: options[:invalidate] || options[:kid_not_found])
      end
    end

    def fetch(force: false)
      @mutex.synchronize do
        return @keys if @keys && !force && !expired?

        @keys = load_keys
        @fetched_at = @clock.call
        @keys
      end
    end

    private

    def expired?
      @fetched_at.nil? || @fetched_at < @clock.call - @ttl
    end

    def load_keys
      response = @http.get(@jwks_url, headers: { "Accept" => "application/json" })

      unless response.success?
        raise VerificationFailed, "Clerk JWKS request returned #{response.status}"
      end

      document = JSON.parse(response.body.to_s)

      unless document.is_a?(Hash) && document["keys"].is_a?(Array)
        raise VerificationFailed, "Clerk JWKS response had no keys"
      end

      document
    rescue HttpClient::TransportError => exception
      raise VerificationFailed, "Clerk JWKS unreachable: #{exception.message}"
    rescue JSON::ParserError => exception
      raise VerificationFailed, "Clerk JWKS was unreadable: #{exception.message}"
    end
  end
end
