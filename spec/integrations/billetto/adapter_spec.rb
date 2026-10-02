require "rails_helper"

RSpec.describe Billetto::Adapter do
  let(:base_url) { "https://billetto.test" }
  let(:first_url) { "#{base_url}/api/v3/public/events?limit=2" }
  let(:second_url) { "#{base_url}/api/v3/public/events?after=2" }

  def event(id)
    { "id" => id, "title" => "Event #{id}", "startdate" => "2026-10-31T19:00:00Z" }
  end

  describe "#each_public_event" do
    it "follows the cursor until has_more goes false" do
      http = StubHttpClient.new(
        first_url => StubHttpClient.json({
          "data" => [ event("1"), event("2") ], "has_more" => true, "next_url" => second_url
        }),
        second_url => StubHttpClient.json({
          "data" => [ event("3") ], "has_more" => false, "next_url" => nil
        })
      )
      adapter = described_class.new(api_keypair: "k:s", base_url: base_url, page_size: 2, http: http)

      ids = adapter.each_public_event.map(&:external_id)

      expect(ids).to eq(%w[1 2 3])
      expect(http.urls).to eq([ first_url, second_url ])
    end

    it "sends the keypair header on every request" do
      http = StubHttpClient.new(
        first_url => StubHttpClient.json({ "data" => [ event("1") ], "has_more" => false })
      )
      adapter = described_class.new(api_keypair: "key:secret", base_url: base_url, page_size: 2, http: http)

      adapter.each_public_event.to_a

      expect(http.requests.first[:headers]).to include("Api-Keypair" => "key:secret")
    end

    it "stops fetching once the limit is reached" do
      http = StubHttpClient.new(
        first_url => StubHttpClient.json({
          "data" => [ event("1"), event("2") ], "has_more" => true, "next_url" => second_url
        })
      )
      adapter = described_class.new(api_keypair: "k:s", base_url: base_url, page_size: 2, http: http)

      expect(adapter.each_public_event(limit: 1).map(&:external_id)).to eq([ "1" ])
      expect(http.requests.size).to eq(1)
    end

    it "stops when has_more is true but no next_url is given" do
      http = StubHttpClient.new(
        first_url => StubHttpClient.json({
          "data" => [ event("1") ], "has_more" => true, "next_url" => nil
        })
      )
      adapter = described_class.new(api_keypair: "k:s", base_url: base_url, page_size: 2, http: http)

      expect(adapter.each_public_event.count).to eq(1)
    end
  end

  describe "failures" do
    def adapter_for(response)
      described_class.new(
        api_keypair: "k:s",
        base_url: base_url,
        page_size: 2,
        http: StubHttpClient.new(first_url => response)
      )
    end

    it "raises AuthenticationFailed on a 401" do
      adapter = adapter_for(StubHttpClient.json({ "error" => "nope" }, status: 401))

      expect { adapter.each_public_event.to_a }
        .to raise_error(Billetto::AuthenticationFailed)
    end

    it "raises AuthenticationFailed when the error arrives in the body with a 200" do
      adapter = adapter_for(StubHttpClient.json({
        "error" => { "message" => "Invalid credentials", "type" => "authentication_error" }
      }))

      expect { adapter.each_public_event.to_a }
        .to raise_error(Billetto::AuthenticationFailed, /Invalid credentials/)
    end

    it "raises RequestFailed on a server error" do
      adapter = adapter_for(StubHttpClient.json({ "error" => "boom" }, status: 503))

      expect { adapter.each_public_event.to_a }
        .to raise_error(Billetto::RequestFailed, /503/)
    end

    it "translates a transport failure into Billetto's own error" do
      http = Object.new
      http.define_singleton_method(:get) do |_url, headers: {}|
        raise HttpClient::TransportError, "GET failed: Timeout::Error"
      end
      adapter = described_class.new(api_keypair: "k:s", base_url: base_url, page_size: 2, http: http)

      expect { adapter.each_public_event.to_a }
        .to raise_error(Billetto::RequestFailed, /Timeout::Error/)
    end

    it "raises RequestFailed when the body is not JSON" do
      adapter = adapter_for(StubHttpClient.raw("<html>nope</html>"))

      expect { adapter.each_public_event.to_a }
        .to raise_error(Billetto::RequestFailed, /unreadable body/)
    end

    it "refuses to be built without a keypair" do
      expect { described_class.new(api_keypair: "") }
        .to raise_error(Billetto::ConfigurationError, /keypair is missing/)
    end
  end
end
