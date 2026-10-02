# frozen_string_literal: true

module ReadModels
  class RebuildEventVoteTallies
    STREAM = "Voting$votes"

    def initialize(event_store: Rails.configuration.event_store, handler: EventVoteTally.new)
      @event_store = event_store
      @handler = handler
    end

    def call(event_tid: nil)
      facts = facts_for(event_tid)
      total = facts.count

      reset!(event_tid)

      applied = 0
      facts.each do |fact|
        @handler.call(fact)
        applied += 1
        yield(applied, total) if block_given?
      end

      { replayed: applied, tallies: scope(event_tid).count }
    end

    private

    def facts_for(event_tid)
      return @event_store.read.stream(STREAM) if event_tid.blank?

      @event_store.read.stream("Event$#{event_tid}")
    end

    def reset!(event_tid)
      ApplicationRecord.transaction do
        scope(event_tid).delete_all
        processed_claims(event_tid).delete_all
      end
    end

    def scope(event_tid)
      relation = EventVoteTally::Count.all
      event_tid.present? ? relation.where(event_tid: event_tid) : relation
    end

    def processed_claims(event_tid)
      claims = ProcessedFact.where(handler: EventVoteTally.name)
      return claims if event_tid.blank?

      claims.where(event_id: facts_for(event_tid).map(&:event_id))
    end
  end
end
