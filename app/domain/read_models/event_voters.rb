# frozen_string_literal: true

module ReadModels
  class EventVoters
    include Handler.async(queue: "low")
    include Handler::Idempotency

    subscribes_to Voting::EventUpvoted,
                  Voting::EventDownvoted,
                  Voting::VoteWithdrawn

    class Voter < ApplicationRecord
      self.table_name = "event_voters"

      scope :liking, -> { where(direction: "up") }
      scope :lapsed, -> { where(ever_upvoted: true).where("direction IS DISTINCT FROM 'up'") }

      def liking? = direction == "up"
      def disliking? = direction == "down"
      def withdrawn? = direction.nil?

      def lapsed? = ever_upvoted? && !liking?
    end

    def call(fact)
      applied = process_once(fact) do
        voter = Voter.find_or_create_by!(
          event_tid: fact.data.fetch(:event_tid),
          user_id: fact.data.fetch(:user_id)
        )

        voter.lock!
        apply(fact, voter)
        voter.save!

        Rails.logger.info do
          "[voters] #{fact.event_type.demodulize} #{voter.event_tid} " \
            "#{voter.user_id} -> #{voter.direction.inspect}"
        end
      end

      applied
    end

    private

    def apply(fact, voter)
      case fact
      when Voting::EventUpvoted
        voter.direction = "up"
        voter.ever_upvoted = true
      when Voting::EventDownvoted
        voter.direction = "down"
      when Voting::VoteWithdrawn
        withdraw(fact, voter)
      end
    end

    def withdraw(fact, voter)
      return unless voter.direction == fact.data.fetch(:previous)

      voter.direction = nil
    end
  end
end
