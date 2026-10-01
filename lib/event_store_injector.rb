# frozen_string_literal: true

module EventStoreInjector
  extend ActiveSupport::Concern

  class_methods do
    def event_store
      Rails.configuration.event_store
    end
  end

  def event_store
    Rails.configuration.event_store
  end
end
