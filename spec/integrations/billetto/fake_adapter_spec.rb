require "rails_helper"

RSpec.describe Billetto::FakeAdapter do
  subject(:adapter) { described_class.new }

  it "reads the checked-in response fixture" do
    expect(adapter.each_public_event.count).to eq(8)
  end

  it "yields payloads the application can map" do
    payload = adapter.each_public_event.first

    expect(payload).to be_a(Billetto::EventPayload)
    expect(payload).to be_valid
    expect(payload.to_attributes[:title]).to be_present
  end

  it "honours a limit" do
    expect(adapter.each_public_event(limit: 3).count).to eq(3)
  end

  it "returns an enumerator when given no block" do
    expect(adapter.each_public_event).to be_a(Enumerator)
  end

  it "complains clearly when the fixture is missing" do
    adapter = described_class.new(fixture_path: Rails.root.join("db/fixtures/nope.json"))

    expect { adapter.each_public_event.to_a }
      .to raise_error(Billetto::ConfigurationError, /fixture missing/)
  end

  it "is the adapter configured for the test environment" do
    expect(Rails.configuration.billetto).to be_a(described_class)
  end
end
