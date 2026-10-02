require "rails_helper"

RSpec.describe ReadModels::RebuildEventVoteTallies do
  let(:command_bus) { Rails.configuration.command_bus }
  let(:events) { create_list(:catalog_event, 3) }

  def vote(event, user_id:, direction: "up")
    perform_enqueued_jobs do
      command_bus.call(
        Voting::CastVote.new(event_tid: event.tid, user_id: user_id, direction: direction)
      )
    end
  end

  def snapshot
    ReadModels::EventVoteTally::Count.order(:event_tid).pluck(:event_tid, :ups, :downs)
  end

  before do
    vote(events[0], user_id: "user_one")
    vote(events[0], user_id: "user_two")
    vote(events[0], user_id: "user_three", direction: "down")
    vote(events[1], user_id: "user_one", direction: "down")
    vote(events[1], user_id: "user_two")
    vote(events[1], user_id: "user_two") # withdrawn again
    vote(events[2], user_id: "user_one")
    vote(events[2], user_id: "user_one", direction: "down") # changed mind
  end

  it "reproduces the tallies exactly after the table is dropped" do
    before_rebuild = snapshot
    ReadModels::EventVoteTally::Count.delete_all

    described_class.new.call

    expect(snapshot).to eq(before_rebuild)
  end

  it "reproduces them even when the table was never dropped" do
    before_rebuild = snapshot

    described_class.new.call

    expect(snapshot).to eq(before_rebuild)
  end

  it "reports what it replayed" do
    report = described_class.new.call

    expect(report[:replayed]).to eq(Rails.configuration.event_store.read.stream("Voting$votes").count)
    expect(report[:tallies]).to eq(3)
  end

  it "yields progress" do
    seen = []

    described_class.new.call { |applied, total| seen << [ applied, total ] }

    expect(seen.first).to eq([ 1, seen.last.last ])
    expect(seen.last.first).to eq(seen.last.last)
  end

  it "survives being run twice" do
    before_rebuild = snapshot

    2.times { described_class.new.call }

    expect(snapshot).to eq(before_rebuild)
  end

  describe "rebuilding a single event" do
    it "restores only that event" do
      before_rebuild = snapshot
      ReadModels::EventVoteTally::Count.delete_all

      described_class.new.call(event_tid: events[0].tid)

      expect(snapshot).to eq([ before_rebuild.find { |tid, *| tid == events[0].tid } ])
    end

    it "leaves the other events' tallies alone" do
      before_rebuild = snapshot

      described_class.new.call(event_tid: events[0].tid)

      expect(snapshot).to eq(before_rebuild)
    end
  end

  it "clears the handler's processed claims so the replay is not refused" do
    ReadModels::EventVoteTally::Count.delete_all

    described_class.new.call

    expect(ReadModels::EventVoteTally::Count.sum(:ups)).to be_positive
  end
end
