# frozen_string_literal: true

Rails.configuration.to_prepare do
  Rails.configuration.command_bus =
    Command::Instrumentation.new(
      Command::Correlation.new(
        Command::Transaction.new(Command::Bus.new),
        -> { Rails.configuration.event_store }
      )
    )
end
