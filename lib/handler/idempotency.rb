# frozen_string_literal: true

module Handler
  # Makes a handler safe to run twice on the same fact.
  module Idempotency
    AlreadyApplied = Class.new(StandardError)

    def process_once(fact)
      ApplicationRecord.transaction(requires_new: true) do
        claim!(fact)

        yield
      end

      true
    rescue AlreadyApplied
      Rails.logger.debug { "[#{self.class.name}] already applied #{fact.event_id}" }

      false
    end

    private

    def claim!(fact)
      ProcessedFact.create!(handler: self.class.name, event_id: fact.event_id)
    rescue ActiveRecord::RecordNotUnique
      raise AlreadyApplied
    end
  end
end
