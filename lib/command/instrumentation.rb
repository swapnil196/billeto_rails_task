# frozen_string_literal: true

module Command
  class Instrumentation
    NAMESPACE = "call.command_bus"

    def initialize(next_bus)
      @next_bus = next_bus
    end

    def call(command)
      ActiveSupport::Notifications.instrument(NAMESPACE, command: command.class.name) do |payload|
        @next_bus.call(command).tap { payload[:result] = :ok }
      rescue StandardError => exception
        payload[:result] = :error
        payload[:exception_class] = exception.class.name
        raise
      end
    end
  end
end
