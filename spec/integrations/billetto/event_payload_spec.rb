require "rails_helper"

RSpec.describe Billetto::EventPayload do
  # Taken from a live response, so the mapping is asserted against the shape
  # the application actually meets.
  let(:raw) do
    {
      "id" => "2022806",
      "object" => "public_event",
      "kind" => "regular",
      "state" => "published",
      "title" => "  The Candlelight Club's Halloween Ball  ",
      "description" => "A Halloween special from London's speakeasy party.",
      "url" => "https://billetto.co.uk/e/plain",
      "branded_url" => "https://billetto.co.uk/e/branded",
      "image_link" => "https://billetto.imgix.net/abc?w=1200",
      "availability" => true,
      "organiser" => { "id" => 182_919, "name" => "Clayton Hartley" },
      "minimum_price" => { "amount_in_cents" => 30, "currency" => "GBP" },
      "categorization" => { "category" => "music", "category_localized" => "Music" },
      "location" => { "location_name" => nil, "address_line" => "A secret ballroom" },
      "startdate" => "2026-10-31T19:00:00Z",
      "enddate" => "2026-11-01T01:00:00Z"
    }
  end

  subject(:payload) { described_class.new(raw) }

  it "flattens Billetto's nested shape into our own vocabulary" do
    expect(payload.to_attributes).to include(
      external_id: "2022806",
      title: "The Candlelight Club's Halloween Ball",
      image_url: "https://billetto.imgix.net/abc?w=1200",
      starts_at: Time.utc(2026, 10, 31, 19, 0, 0),
      ends_at: Time.utc(2026, 11, 1, 1, 0, 0),
      organiser_name: "Clayton Hartley",
      category: "Music",
      minimum_price_cents: 30,
      currency: "GBP",
      available: true
    )
  end

  it "prefers the branded url over the plain one" do
    expect(payload.to_attributes[:event_url]).to eq("https://billetto.co.uk/e/branded")
  end

  it "falls back to the address line when the venue has no name" do
    expect(payload.to_attributes[:venue_name]).to eq("A secret ballroom")
  end

  it "coerces the external id to a string so it is stable across types" do
    expect(described_class.new(raw.merge("id" => 2_022_806)).external_id).to eq("2022806")
  end

  describe "validity" do
    it "accepts a payload carrying id, title and startdate" do
      expect(payload).to be_valid
    end

    it "rejects a payload with no title" do
      payload = described_class.new(raw.merge("title" => "  "))

      expect(payload).not_to be_valid
      expect(payload.errors.join).to match(/missing title/)
    end

    it "rejects a payload with no start date" do
      expect(described_class.new(raw.except("startdate"))).not_to be_valid
    end

    it "rejects a start date it cannot read" do
      payload = described_class.new(raw.merge("startdate" => "not a date"))

      expect(payload).not_to be_valid
      expect(payload.errors.join).to match(/not a timestamp/)
    end

    it "raises from #validate! with the offending id named" do
      expect { described_class.new(raw.except("title")).validate! }
        .to raise_error(Billetto::InvalidPayload, /2022806.*missing title/)
    end

    it "treats a missing end date as absent rather than guessing" do
      expect(described_class.new(raw.except("enddate")).ends_at).to be_nil
    end

    it "survives a payload that is not a hash at all" do
      expect(described_class.new(nil)).not_to be_valid
    end
  end
end
