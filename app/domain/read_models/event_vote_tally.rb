# frozen_string_literal: true

module ReadModels
  class EventVoteTally
    include Handler.async(queue: "low")
    include Handler::Idempotency

    subscribes_to Voting::EventUpvoted,
                  Voting::EventDownvoted,
                  Voting::VoteWithdrawn

    class Count < ApplicationRecord
      self.table_name = "event_vote_tallies"
    end

    def call(fact)
      process_once(fact) do
        count = Count.find_or_create_by!(event_tid: fact.data.fetch(:event_tid))

        count.lock!
        apply(fact, count)
        count.save!
      end
    end

    private

    def apply(fact, count)
      case fact
      when Voting::EventUpvoted then count.ups += 1
      when Voting::EventDownvoted then count.downs += 1
      when Voting::VoteWithdrawn then withdraw(fact, count)
      end
    end

    def withdraw(fact, count)
      case fact.data.fetch(:previous)
      when "up" then count.ups = [ count.ups - 1, 0 ].max
      when "down" then count.downs = [ count.downs - 1, 0 ].max
      end
    end
  end
end
