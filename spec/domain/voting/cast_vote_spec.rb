require "rails_helper"

RSpec.describe Voting::CastVote, :isolated_event_store do
  let(:command_bus) { Rails.configuration.command_bus }
  let(:event_store) { Rails.configuration.event_store }
  let(:event) { create(:catalog_event) }
  let(:user_id) { "user_abc" }

  def vote(direction, by: user_id, on: event)
    command_bus.call(
      described_class.new(event_tid: on.tid, user_id: by, direction: direction)
    )
  end

  def facts
    event_store.read.stream("Voting$votes").to_a
  end

  describe "a first vote" do
    it "reports that it was cast" do
      expect(vote("up")).to be_cast
    end

    it "publishes EventUpvoted" do
      vote("up")

      expect(facts.map(&:class)).to eq([ Voting::EventUpvoted ])
      expect(facts.first.data).to eq(event_tid: event.tid, user_id: user_id)
    end

    it "publishes EventDownvoted for a dislike" do
      vote("down")

      expect(facts.map(&:class)).to eq([ Voting::EventDownvoted ])
    end

    it "records the ballot" do
      expect { vote("up") }.to change(Voting::Ballot, :count).by(1)
    end

    it "is readable from the event's own stream" do
      vote("up")

      expect(event_store.read.stream("Event$#{event.tid}").last)
        .to be_a(Voting::EventUpvoted)
    end

    it "is readable from the voter's stream" do
      vote("up")

      expect(event_store.read.stream("User$#{user_id}").count).to eq(1)
    end

    it "stores the fact once despite the three streams" do
      vote("up")

      expect(event_store.read.count).to eq(1)
    end
  end

  describe "voting the same way twice" do
    before { vote("up") }

    it "reports the vote as withdrawn" do
      expect(vote("up")).to be_withdrawn
    end

    it "publishes VoteWithdrawn naming what it undid" do
      vote("up")

      expect(facts.last).to be_a(Voting::VoteWithdrawn)
      expect(facts.last.data[:previous]).to eq("up")
    end

    it "removes the ballot" do
      expect { vote("up") }.to change(Voting::Ballot, :count).by(-1)
    end

    it "leaves the original vote in the log" do
      vote("up")

      expect(facts.first).to be_a(Voting::EventUpvoted)
    end
  end

  describe "changing your mind" do
    before { vote("up") }

    it "reports the vote as changed" do
      expect(vote("down")).to be_changed
    end

    it "withdraws the old vote before recording the new one" do
      vote("down")

      expect(facts.map(&:class)).to eq([
        Voting::EventUpvoted,
        Voting::VoteWithdrawn,
        Voting::EventDownvoted
      ])
    end

    it "says which direction was withdrawn" do
      vote("down")

      expect(facts[1].data[:previous]).to eq("up")
    end

    it "keeps one ballot, pointing the other way" do
      expect { vote("down") }.not_to change(Voting::Ballot, :count)
      expect(Voting::Ballot.sole.direction).to eq("down")
    end
  end

  describe "independence" do
    it "lets different people vote on the same event" do
      vote("up", by: "user_one")
      vote("down", by: "user_two")

      expect(Voting::Ballot.count).to eq(2)
      expect(facts.size).to eq(2)
    end

    it "lets one person vote on different events" do
      other = create(:catalog_event)

      vote("up")
      vote("up", on: other)

      expect(event_store.read.stream("User$#{user_id}").count).to eq(2)
    end
  end

  describe "refusing bad commands" do
    it "rejects an unknown direction" do
      expect { vote("sideways") }
        .to raise_error(Command::Invalid, /must be up or down/)
    end

    it "rejects a vote with no voter" do
      expect { vote("up", by: "") }
        .to raise_error(Command::Invalid, /User can't be blank/)
    end

    it "publishes nothing when the command is refused" do
      begin
        vote("sideways")
      rescue Command::Invalid
        # expected
      end

      expect(facts).to be_empty
    end
  end

  describe "the database as the final arbiter" do
    # insert! rather than insert: the latter is ON CONFLICT DO NOTHING, which
    # would swallow exactly the collision this is asserting on.
    it "refuses a second ballot for the same person and event" do
      vote("up")

      expect {
        Voting::Ballot.insert!({ event_tid: event.tid, user_id: user_id, direction: "down",
                                created_at: Time.current, updated_at: Time.current })
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
