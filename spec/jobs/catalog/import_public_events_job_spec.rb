require "rails_helper"

RSpec.describe Catalog::ImportPublicEventsJob, :isolated_event_store, type: :job do
  let(:event_store) { Rails.configuration.event_store }

  def run(limit: nil)
    described_class.perform_now(limit: limit)
  end

  describe "against the captured Billetto response" do
    it "imports every event in the fixture" do
      expect { run }.to change(Catalog::Event, :count).by(8)
    end

    it "reports what it did" do
      expect(run).to eq(seen: 8, invalid: 0, failed: 0, created: 8, updated: 0, unchanged: 0)
    end

    it "honours a limit" do
      expect { run(limit: 3) }.to change(Catalog::Event, :count).by(3)
    end

    it "maps the real payload onto the model" do
      run(limit: 1)

      event = Catalog::Event.find_by(external_id: "2022806")
      expect(event.title).to eq("The Candlelight Club's Halloween Ball")
      expect(event.starts_at).to eq(Time.utc(2026, 10, 31, 19, 0, 0))
      expect(event.organiser_name).to be_present
    end
  end

  describe "running twice" do
    before { run }

    it "creates nothing the second time" do
      expect { run }.not_to change(Catalog::Event, :count)
    end

    it "publishes nothing the second time" do
      expect { run }.not_to change { event_store.read.count }
    end

    it "reports the events as unchanged rather than written" do
      expect(run).to eq(seen: 8, invalid: 0, failed: 0, created: 0, updated: 0, unchanged: 8)
    end
  end

  describe "when an event upstream is unusable" do
    let(:payloads) do
      [
        { "id" => "1", "title" => "Fine", "startdate" => "2026-10-31T19:00:00Z" },
        { "id" => "2", "title" => "", "startdate" => "2026-10-31T19:00:00Z" },
        { "id" => "3", "title" => "Also fine", "startdate" => "2026-11-30T19:00:00Z" }
      ]
    end

    before do
      allow(Rails.configuration).to receive(:billetto)
        .and_return(Billetto::FakeAdapter.new(payloads: payloads))
    end

    it "skips it and imports the rest" do
      expect { run }.to change(Catalog::Event, :count).by(2)
    end

    it "counts the skip rather than failing the run" do
      expect(run).to eq(seen: 3, invalid: 1, failed: 0, created: 2, updated: 0, unchanged: 0)
    end
  end

  describe "when the domain refuses one event" do
    let(:payloads) do
      [
        { "id" => "1", "title" => "Fine", "startdate" => "2026-10-31T19:00:00Z" },
        # Ends before it starts: survives payload validation, refused by the model.
        { "id" => "2", "title" => "Backwards", "startdate" => "2026-11-30T19:00:00Z",
          "enddate" => "2026-11-29T19:00:00Z" },
        { "id" => "3", "title" => "Also fine", "startdate" => "2026-12-30T19:00:00Z" }
      ]
    end

    before do
      allow(Rails.configuration).to receive(:billetto)
        .and_return(Billetto::FakeAdapter.new(payloads: payloads))
    end

    it "imports the others" do
      expect { run }.to change(Catalog::Event, :count).by(2)
    end

    it "counts the failure without aborting" do
      expect(run).to eq(seen: 3, invalid: 0, failed: 1, created: 2, updated: 0, unchanged: 0)
    end

    it "leaves no trace of the refused event" do
      run

      expect(Catalog::Event.find_by(external_id: "2")).to be_nil
      expect(event_store.read.count).to eq(2)
    end
  end

  describe "transport failures" do
    def adapter_raising(error)
      adapter = Object.new
      adapter.define_singleton_method(:each_public_event) { |limit: nil| raise error }
      adapter
    end

    it "retries a request failure, since the whole run failed rather than one event" do
      allow(Rails.configuration).to receive(:billetto)
        .and_return(adapter_raising(Billetto::RequestFailed.new("timeout")))

      expect { described_class.perform_now }.to have_enqueued_job(described_class)
    end

    it "discards an authentication failure, which retrying cannot fix" do
      allow(Rails.configuration).to receive(:billetto)
        .and_return(adapter_raising(Billetto::AuthenticationFailed.new("bad key")))

      expect { described_class.perform_now }.not_to raise_error
      expect(described_class).not_to have_been_enqueued
    end
  end
end
