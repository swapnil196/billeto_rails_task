# frozen_string_literal: true

module Command
  class Transaction
    def initialize(next_bus)
      @next_bus = next_bus
    end

    def call(command)
      ApplicationRecord.transaction { @next_bus.call(command) }
    end
  end
end
