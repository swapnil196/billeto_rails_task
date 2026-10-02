# frozen_string_literal: true

module Voting
  DIRECTIONS = %w[up down].freeze

  module Streams
    def self.for(event_tid:, user_id:)
      [ "Event$#{event_tid}", "User$#{user_id}", "Voting$votes" ]
    end
  end

  class EventUpvoted < Fact
    SCHEMA = { event_tid: String, user_id: String }.freeze

    def stream_names
      Streams.for(event_tid: data.fetch(:event_tid), user_id: data.fetch(:user_id))
    end
  end

  class EventDownvoted < Fact
    SCHEMA = { event_tid: String, user_id: String }.freeze

    def stream_names
      Streams.for(event_tid: data.fetch(:event_tid), user_id: data.fetch(:user_id))
    end
  end

  class VoteWithdrawn < Fact
    SCHEMA = { event_tid: String, user_id: String, previous: String }.freeze

    def stream_names
      Streams.for(event_tid: data.fetch(:event_tid), user_id: data.fetch(:user_id))
    end
  end

  def self.fact_for(direction)
    case direction
    when "up" then EventUpvoted
    when "down" then EventDownvoted
    else raise ArgumentError, "unknown vote direction #{direction.inspect}"
    end
  end

  def self.subscriptions
    [].reduce({}) { |merged, subscriptions| merged.merge(subscriptions) }
  end
end
