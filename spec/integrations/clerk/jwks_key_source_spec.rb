require "rails_helper"

RSpec.describe Clerk::JwksKeySource do
  let(:jwks_url) { "https://clerk.test/.well-known/jwks.json" }
  let(:document) { ClerkTokenFactory.jwks }
  let(:http) { StubHttpClient.new(jwks_url => StubHttpClient.json(document)) }

  subject(:source) { described_class.new(jwks_url: jwks_url, http: http) }

  it "fetches the key set" do
    expect(source.fetch["keys"].first["kid"]).to eq(ClerkTokenFactory.kid)
  end

  it "caches it rather than fetching per verification" do
    3.times { source.fetch }

    expect(http.requests.size).to eq(1)
  end

  it "refetches when asked to force a refresh" do
    source.fetch
    source.fetch(force: true)

    expect(http.requests.size).to eq(2)
  end

  it "refetches once the cache has aged out" do
    now = Time.current
    source = described_class.new(jwks_url: jwks_url, http: http, ttl: 1.hour, clock: -> { now })
    source.fetch

    now += 2.hours
    source.fetch

    expect(http.requests.size).to eq(2)
  end

  describe "the loader handed to the jwt gem" do
    it "serves the cached set for a key id it already knows" do
      source.fetch

      expect(source.to_jwk_loader.call({})).to eq(document)
      expect(http.requests.size).to eq(1)
    end

    it "refreshes when the token names a key id the cache does not have" do
      source.fetch

      source.to_jwk_loader.call(kid_not_found: true)

      expect(http.requests.size).to eq(2)
    end
  end

  describe "failures" do
    it "refuses a url that was never configured" do
      expect { described_class.new(jwks_url: nil) }
        .to raise_error(Clerk::ConfigurationError, /JWKS url is missing/)
    end

    it "reports an unreachable endpoint as a verification failure" do
      http = Object.new
      http.define_singleton_method(:get) do |_url, headers: {}|
        raise HttpClient::TransportError, "GET failed: Timeout::Error"
      end

      expect { described_class.new(jwks_url: jwks_url, http: http).fetch }
        .to raise_error(Clerk::VerificationFailed, /unreachable/)
    end

    it "reports a non-success response" do
      http = StubHttpClient.new(jwks_url => StubHttpClient.json({}, status: 500))

      expect { described_class.new(jwks_url: jwks_url, http: http).fetch }
        .to raise_error(Clerk::VerificationFailed, /returned 500/)
    end

    it "reports a body that is not a key set" do
      http = StubHttpClient.new(jwks_url => StubHttpClient.json({ "nope" => true }))

      expect { described_class.new(jwks_url: jwks_url, http: http).fetch }
        .to raise_error(Clerk::VerificationFailed, /no keys/)
    end

    it "reports an unreadable body" do
      http = StubHttpClient.new(jwks_url => StubHttpClient.raw("<html>"))

      expect { described_class.new(jwks_url: jwks_url, http: http).fetch }
        .to raise_error(Clerk::VerificationFailed, /unreadable/)
    end
  end
end
