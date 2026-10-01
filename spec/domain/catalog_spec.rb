require "rails_helper"

RSpec.describe Catalog do
  describe Catalog::EventImported do
    it "is published to the event's stream and the catalogue-wide one" do
      fact = described_class.strict(
        data: { tid: "evt_abc", external_id: "2022806", title: "A Ball" }
      )

      expect(fact.stream_names).to eq([ "Event$evt_abc", "Catalog$imports" ])
    end

    it "refuses a payload missing the external id" do
      expect {
        described_class.strict(data: { tid: "evt_abc", title: "A Ball" })
      }.to raise_error(Fact::SchemaViolation, /missing keys: external_id/)
    end
  end

  describe Catalog::EventUpdated do
    it "records which attributes changed" do
      fact = described_class.strict(
        data: { tid: "evt_abc", external_id: "2022806", changed: %w[title starts_at] }
      )

      expect(fact.data[:changed]).to eq(%w[title starts_at])
    end

    it "requires the changed list to be an array" do
      expect {
        described_class.strict(data: { tid: "evt_abc", external_id: "2022806", changed: "title" })
      }.to raise_error(Fact::SchemaViolation, /changed expected Array, got String/)
    end
  end
end
