# frozen_string_literal: true

module Command
  class Correlation
    def initialize(next_bus, event_store_provider)
      @next_bus = next_bus
      @event_store_provider = event_store_provider
    end

    def call(command)
      event_store = @event_store_provider.call
      current = event_store.metadata[:correlation_id]

      event_store.with_metadata(
        correlation_id: current || SecureRandom.uuid,
        command: command.class.name
      ) do
        @next_bus.call(command)
      end
    end
  end
end
