# frozen_string_literal: true

module Handler
  # Makes a handler safe to run twice on the same fact.
  module Idempotency
    def process_once(fact)
      ApplicationRecord.transaction(requires_new: true) do
        ProcessedFact.create!(handler: self.class.name, event_id: fact.event_id)

        yield
      end

      true
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.debug { "[#{self.class.name}] already applied #{fact.event_id}" }

      false
    end
  end
end
