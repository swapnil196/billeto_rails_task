# frozen_string_literal: true

class ApplicationSubscriptions
  def call(event_store)
    handlers.each do |fact_class, subscribers|
      subscribers.each { |subscriber| event_store.subscribe(subscriber, to: [ fact_class ]) }
    end
  end

  def handlers
    [
      Catalog.subscriptions,
      Voting.subscriptions,
      ReadModels::EventVoteTally.subscriptions
    ].reduce({}) { |merged, subscriptions| merge(merged, subscriptions) }
  end

  private

  def merge(left, right)
    left.merge(right) { |_fact, a, b| (a | b) }
  end
end
