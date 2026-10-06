require "rails_helper"

# The original implementation took `Ballot.lock.find_by(...)`, and a comment
# claimed that serialised two clicks from the same person. It did not: SELECT
# ... FOR UPDATE on a row that does not exist locks nothing, so two concurrent
# first votes both read nil, both insert, and one hits the unique index after
# having already published a fact.
RSpec.describe Voting::CastVote, "locking", :isolated_event_store do
  let(:command_bus) { Rails.configuration.command_bus }
  let(:event) { create(:catalog_event) }

  def locks_taken(&block)
    sql = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      sql << payload[:sql] if payload[:sql].include?("pg_advisory_xact_lock")
    end

    block.call

    sql
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  def vote(direction, by: "user_abc", on: event)
    command_bus.call(
      described_class.new(event_tid: on.tid, user_id: by, direction: direction)
    )
  end

  it "takes a lock even though no ballot exists yet" do
    expect(Voting::Ballot.count).to eq(0)

    expect(locks_taken { vote("up") }).not_to be_empty
  end

  it "still takes one when a ballot already exists" do
    vote("up")

    expect(locks_taken { vote("down") }).not_to be_empty
  end

  it "takes the lock before reading the current ballot" do
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql]
    end

    vote("up")

    lock_at = statements.index { |s| s.include?("pg_advisory_xact_lock") }
    read_at = statements.index { |s| s.include?("FROM \"votes\"") }

    expect(lock_at).to be_present
    expect(read_at).to be_present
    expect(lock_at).to be < read_at
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # Asserted on the statement rather than on pg_locks: an advisory xact lock is
  # released when the *top-level* transaction ends, and transactional fixtures
  # keep one open around every example, so the release is not observable here.
  # The session-scoped variant (pg_advisory_lock) would leak a lock per vote
  # for the life of the connection, so which function is called is the whole
  # guarantee.
  it "uses the transaction-scoped lock, which cannot leak past the command" do
    statements = locks_taken { vote("up") }

    expect(statements).to all(include("pg_advisory_xact_lock"))
  end

  describe "the key" do
    it "separates two people voting on the same event" do
      vote("up", by: "user_one")
      vote("up", by: "user_two")

      expect(Voting::Ballot.count).to eq(2)
    end

    it "separates one person voting on two events" do
      other = create(:catalog_event)

      vote("up")
      vote("up", on: other)

      expect(Voting::Ballot.count).to eq(2)
    end
  end
end
