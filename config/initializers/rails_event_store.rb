# frozen_string_literal: true

Rails.configuration.to_prepare do
  Rails.configuration.event_store = ApplicationEventStore.build
  ApplicationSubscriptions.new.call(Rails.configuration.event_store)
end
