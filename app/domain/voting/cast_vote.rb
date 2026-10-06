# frozen_string_literal: true

module Voting
  class CastVote
    include Command::Executable

    Result = Struct.new(:outcome, :direction) do
      def cast? = outcome == :cast
      def changed? = outcome == :changed
      def withdrawn? = outcome == :withdrawn
    end

    attribute :event_tid, String
    attribute :user_id, String
    attribute :direction, String

    validates :event_tid, presence: true
    validates :user_id, presence: true
    validates :direction, inclusion: { in: DIRECTIONS, message: "must be up or down" }

    def call
      serialise_voter!

      existing = Ballot.find_by(event_tid: event_tid, user_id: user_id)

      return cast if existing.nil?
      return withdraw(existing) if existing.direction == direction

      change(existing)
    end

    private

    # A row lock cannot serialise a vote that does not exist yet. `SELECT ...
    # FOR UPDATE` on a missing row locks nothing, so two concurrent first
    # clicks both read "no existing vote", both insert, and one of them hits
    # the unique index as an unhandled error -- after having published a fact
    # that cannot be taken back.
    #
    # An advisory lock keyed on the (event, voter) pair serialises them whether
    # or not a row exists. It is transaction-scoped, and the command bus wraps
    # every command in a transaction, so it is released the moment this command
    # finishes either way.
    def serialise_voter!
      ApplicationRecord.connection.execute(
        ApplicationRecord.sanitize_sql_array(
          [ "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))", lock_key ]
        )
      )
    end

    def lock_key
      "voting.cast_vote:#{event_tid}:#{user_id}"
    end

    def cast
      Ballot.create!(event_tid: event_tid, user_id: user_id, direction: direction)
      publish_vote

      Result.new(:cast, direction)
    end

    def withdraw(existing)
      previous = existing.direction
      existing.destroy!
      publish_withdrawal(previous)

      Result.new(:withdrawn, previous)
    end

    def change(existing)
      previous = existing.direction
      existing.update!(direction: direction)

      publish_withdrawal(previous)
      publish_vote

      Result.new(:changed, direction)
    end

    def publish_vote
      event_store.publish(
        Voting.fact_for(direction).strict(
          data: { event_tid: event_tid, user_id: user_id }
        )
      )
    end

    def publish_withdrawal(previous)
      event_store.publish(
        VoteWithdrawn.strict(
          data: { event_tid: event_tid, user_id: user_id, previous: previous }
        )
      )
    end
  end
end
