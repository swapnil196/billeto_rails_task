require "rails_helper"

RSpec.describe Catalog::ImportEvent, :isolated_event_store do
  let(:command_bus) { Rails.configuration.command_bus }
  let(:event_store) { Rails.configuration.event_store }

  let(:payload_attributes) do
    {
      title: "The Candlelight Club's Halloween Ball",
      description: "A Halloween special.",
      image_url: "https://billetto.imgix.net/abc",
      event_url: "https://billetto.co.uk/e/branded",
      starts_at: Time.utc(2026, 10, 31, 19, 0, 0),
      ends_at: Time.utc(2026, 11, 1, 1, 0, 0),
      state: "published",
      kind: "regular",
      available: true,
      organiser_name: "Clayton Hartley",
      venue_name: "A secret ballroom",
      category: "Music",
      minimum_price_cents: 30,
      currency: "GBP"
    }
  end

  def import(external_id: "2022806", **overrides)
    command_bus.call(
      described_class.new(
        external_id: external_id,
        payload_attributes: payload_attributes.merge(overrides)
      )
    )
  end

  describe "the first time an event is seen" do
    it "reports that it created the event" do
      expect(import).to have_attributes(outcome: :created)
    end

    it "creates the event" do
      expect { import }.to change(Catalog::Event, :count).by(1)
    end

    it "stores the mapped attributes" do
      import

      event = Catalog::Event.find_by(external_id: "2022806")
      expect(event.title).to eq("The Candlelight Club's Halloween Ball")
      expect(event.starts_at).to eq(Time.utc(2026, 10, 31, 19, 0, 0))
      expect(event.category).to eq("Music")
    end

    it "publishes EventImported into the event's own stream" do
      import

      event = Catalog::Event.find_by(external_id: "2022806")
      facts = event_store.read.stream("Event$#{event.tid}").to_a

      expect(facts.map(&:class)).to eq([ Catalog::EventImported ])
      expect(facts.first.data).to include(external_id: "2022806")
    end

    it "links the fact into the catalogue-wide import stream" do
      import

      expect(event_store.read.stream("Catalog$imports").count).to eq(1)
    end
  end

  describe "re-importing an unchanged event" do
    before { import }

    it "reports the event as unchanged" do
      expect(import).to be_unchanged
    end

    it "creates nothing further" do
      expect { import }.not_to change(Catalog::Event, :count)
    end

    it "publishes nothing further" do
      expect { import }.not_to change { event_store.read.count }
    end

    it "does not touch the row" do
      event = Catalog::Event.find_by(external_id: "2022806")

      expect { import }.not_to change { event.reload.updated_at }
    end
  end

  describe "re-importing a changed event" do
    before { import }

    it "reports the event as updated" do
      expect(import(title: "Renamed Ball")).to be_updated
    end

    it "updates the stored attributes" do
      import(title: "Renamed Ball")

      expect(Catalog::Event.find_by(external_id: "2022806").title).to eq("Renamed Ball")
    end

    it "publishes EventUpdated naming what changed" do
      import(
        title: "Renamed Ball",
        starts_at: Time.utc(2026, 11, 1, 20, 0, 0),
        ends_at: Time.utc(2026, 11, 2, 1, 0, 0)
      )

      fact = event_store.read.stream("Catalog$imports").last

      expect(fact).to be_a(Catalog::EventUpdated)
      expect(fact.data[:changed]).to match_array(%w[title starts_at ends_at])
    end

    it "keeps the tid it was first given" do
      original = Catalog::Event.find_by(external_id: "2022806").tid

      import(title: "Renamed Ball")

      expect(Catalog::Event.find_by(external_id: "2022806").tid).to eq(original)
    end

    it "treats the same instant in another zone as unchanged" do
      expect { import(starts_at: Time.utc(2026, 10, 31, 19, 0, 0).in_time_zone("Tokyo")) }
        .not_to change { event_store.read.count }
    end
  end

  describe "refusing bad commands" do
    it "rejects a command with no external id" do
      expect {
        command_bus.call(described_class.new(external_id: "", payload_attributes: payload_attributes))
      }.to raise_error(Command::Invalid, /External can't be blank/)
    end

    it "rejects a command with no attributes" do
      expect {
        command_bus.call(described_class.new(external_id: "1", payload_attributes: {}))
      }.to raise_error(Command::Invalid, /must be a hash/)
    end

    it "rolls back the event when the record is invalid" do
      expect {
        begin
          import(title: "")
        rescue ActiveRecord::RecordInvalid
          # expected
        end
      }.not_to change(Catalog::Event, :count)
    end

    it "publishes nothing when the record is invalid" do
      expect {
        begin
          import(title: "")
        rescue ActiveRecord::RecordInvalid
          # expected
        end
      }.not_to change { event_store.read.count }
    end
  end
end
