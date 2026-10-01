# frozen_string_literal: true

module Catalog
  # An event we had not seen before has entered the catalogue.
  class EventImported < Fact
    SCHEMA = {
      tid: String,
      external_id: String,
      title: String
    }.freeze

    def stream_names
      [ "Event$#{data.fetch(:tid)}", "Catalog$imports" ]
    end
  end

  # A later import found different values for an event we already had.
  class EventUpdated < Fact
    SCHEMA = {
      tid: String,
      external_id: String,
      changed: Array
    }.freeze

    def stream_names
      [ "Event$#{data.fetch(:tid)}", "Catalog$imports" ]
    end
  end

  def self.subscriptions
    [].reduce({}) { |merged, subscriptions| merged.merge(subscriptions) }
  end
end
