# frozen_string_literal: true

class ApplicationEventStore < SimpleDelegator
  def self.build
    broker = RubyEventStore::Broker.new(
      subscriptions: RubyEventStore::Subscriptions.new,
      dispatcher: RubyEventStore::ComposedDispatcher.new(
        RailsEventStore::AfterCommitDispatcher.new(
          scheduler: RailsEventStore::ActiveJobScheduler.new(serializer: JSON)
        ),
        RubyEventStore::SyncScheduler.new
      )
    )

    new(RailsEventStore::JSONClient.new(message_broker: broker))
  end

  def publish(fact, **options)
    streams = Array(fact.stream_names)

    if streams.empty?
      raise ArgumentError, "#{fact.class.name} declared no stream names"
    end

    primary, *linked = streams

    __getobj__.publish(fact, stream_name: primary, **options)
    linked.each { |stream| __getobj__.link(fact.event_id, stream_name: stream) }

    fact
  end
end
