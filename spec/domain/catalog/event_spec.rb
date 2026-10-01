require "rails_helper"

RSpec.describe Catalog::Event do
  subject(:event) { build(:catalog_event) }

  it "is valid with the attributes an import produces" do
    expect(event).to be_valid
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_presence_of(:external_id) }

    it "refuses a second event with the same Billetto id" do
      create(:catalog_event, external_id: "2022806")

      duplicate = build(:catalog_event, external_id: "2022806")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_id]).to include("has already been taken")
    end

    it "refuses an end time before the start time" do
      event.ends_at = event.starts_at - 1.hour

      expect(event).not_to be_valid
      expect(event.errors[:ends_at]).to include("must not be before the start time")
    end

    it "accepts an event with no end time at all" do
      event.ends_at = nil

      expect(event).to be_valid
    end

    it "accepts an event that starts and ends at the same instant" do
      event.ends_at = event.starts_at

      expect(event).to be_valid
    end
  end

  describe "the typeid" do
    it "is assigned on creation with an evt_ prefix" do
      event.save!

      expect(event.tid).to match(/\Aevt_[A-Za-z0-9]{16}\z/)
    end

    it "is not reissued on later saves" do
      event.save!
      original = event.tid

      event.update!(title: "A different title")

      expect(event.reload.tid).to eq(original)
    end

    it "is what the record is addressed by in urls" do
      event.save!

      expect(event.to_param).to eq(event.tid)
    end

    it "is unique across events" do
      tids = create_list(:catalog_event, 3).map(&:tid)

      expect(tids.uniq.size).to eq(3)
    end
  end

  describe ".digest_for" do
    let(:attributes) { build(:catalog_event).attributes.symbolize_keys }

    it "is stable for the same values" do
      expect(described_class.digest_for(attributes))
        .to eq(described_class.digest_for(attributes))
    end

    it "changes when a descriptive attribute changes" do
      expect(described_class.digest_for(attributes))
        .not_to eq(described_class.digest_for(attributes.merge(title: "Something else")))
    end

    it "ignores attributes that do not describe the event" do
      expect(described_class.digest_for(attributes))
        .to eq(described_class.digest_for(attributes.merge(external_id: "999", tid: "evt_other")))
    end

    it "treats the same instant in a different zone as unchanged" do
      utc = attributes[:starts_at].utc

      expect(described_class.digest_for(attributes.merge(starts_at: utc)))
        .to eq(described_class.digest_for(attributes.merge(starts_at: utc.in_time_zone("Tokyo"))))
    end
  end

  describe "scopes" do
    it "orders by start date" do
      late = create(:catalog_event, starts_at: 3.weeks.from_now)
      early = create(:catalog_event, starts_at: 1.week.from_now)

      expect(described_class.by_start_date.to_a).to eq([ early, late ])
    end

    it "excludes events that have already started" do
      create(:catalog_event, :past)
      upcoming = create(:catalog_event)

      expect(described_class.upcoming.to_a).to eq([ upcoming ])
    end
  end
end
