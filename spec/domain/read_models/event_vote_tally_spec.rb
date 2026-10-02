require "rails_helper"

RSpec.describe ReadModels::EventVoteTally do
  let(:command_bus) { Rails.configuration.command_bus }
  let(:event) { create(:catalog_event) }

  def vote(direction, by: "user_abc", on: event)
    perform_enqueued_jobs do
      command_bus.call(
        Voting::CastVote.new(event_tid: on.tid, user_id: by, direction: direction)
      )
    end
  end

  def tally(on: event)
    described_class::Count.find_by(event_tid: on.tid)
  end

  describe "counting" do
    it "counts a like" do
      vote("up")

      expect(tally).to have_attributes(ups: 1, downs: 0)
    end

    it "counts a dislike" do
      vote("down")

      expect(tally).to have_attributes(ups: 0, downs: 1)
    end

    it "counts votes from different people" do
      vote("up", by: "user_one")
      vote("up", by: "user_two")
      vote("down", by: "user_three")

      expect(tally).to have_attributes(ups: 2, downs: 1)
    end

    it "keeps events apart" do
      other = create(:catalog_event)

      vote("up")
      vote("up", on: other)
      vote("up", by: "user_two", on: other)

      expect(tally.ups).to eq(1)
      expect(tally(on: other).ups).to eq(2)
    end
  end

  describe "taking a vote back" do
    it "decrements when a like is withdrawn" do
      vote("up")
      vote("up")

      expect(tally).to have_attributes(ups: 0, downs: 0)
    end

    it "moves the count when somebody changes their mind" do
      vote("up")
      vote("down")

      expect(tally).to have_attributes(ups: 0, downs: 1)
    end

    it "never goes below zero" do
      vote("up")
      vote("up")
      vote("up")
      vote("up")

      expect(tally.ups).to eq(0)
    end
  end

  describe "eventual consistency" do
    it "does not update the tally inside the request that voted" do
      command_bus.call(
        Voting::CastVote.new(event_tid: event.tid, user_id: "user_abc", direction: "up")
      )

      expect(tally).to be_nil
    end

    it "catches up once the queue is drained" do
      command_bus.call(
        Voting::CastVote.new(event_tid: event.tid, user_id: "user_abc", direction: "up")
      )

      perform_enqueued_jobs

      expect(tally.ups).to eq(1)
    end
  end

  describe "at-least-once delivery" do
    it "applies a redelivered fact only once" do
      vote("up")
      fact = Rails.configuration.event_store.read.stream("Voting$votes").first

      described_class.new.call(fact)
      described_class.new.call(fact)

      expect(tally.ups).to eq(1)
    end

    it "reports whether it did the work" do
      vote("up")
      fact = Rails.configuration.event_store.read.stream("Voting$votes").first

      expect(described_class.new.call(fact)).to be(false)
    end

    it "records the facts it has applied" do
      vote("up")

      expect(ProcessedFact.where(handler: described_class.name).count).to eq(1)
    end
  end
end
