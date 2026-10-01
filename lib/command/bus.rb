# frozen_string_literal: true

module Command
  class Bus
    def call(command)
      validate!(command)

      unless command.is_a?(Command::Executable)
        raise Unhandled, "#{command.class.name} is not executable"
      end

      command.call
    end

    private

    def validate!(command)
      return unless command.respond_to?(:invalid?)
      return unless command.invalid?

      raise Invalid, "#{command.class.name}: #{command.errors.full_messages.join(', ')}"
    end
  end
end
