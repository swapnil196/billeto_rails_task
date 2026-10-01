# frozen_string_literal: true

module Billetto
  class EventPayload
    REQUIRED_KEYS = %w[id title startdate].freeze

    def initialize(raw)
      @raw = raw.is_a?(Hash) ? raw.with_indifferent_access : {}.with_indifferent_access
    end

    attr_reader :raw

    def valid?
      errors.empty?
    end

    def errors
      @errors ||= begin
        missing = REQUIRED_KEYS.reject { |key| raw[key].presence }
        problems = []
        problems << "missing #{missing.join(', ')}" if missing.any?
        problems << "startdate is not a timestamp" if raw[:startdate].present? && starts_at.nil?
        problems
      end
    end

    def validate!
      return self if valid?

      raise InvalidPayload, "event #{raw[:id].inspect}: #{errors.join('; ')}"
    end

    def external_id
      raw[:id].to_s
    end

    def to_attributes
      {
        external_id: external_id,
        title: raw[:title].to_s.strip,
        description: raw[:description].to_s.strip.presence,
        image_url: raw[:image_link].presence,
        event_url: (raw[:branded_url].presence || raw[:url].presence),
        starts_at: starts_at,
        ends_at: ends_at,
        state: raw[:state].presence,
        kind: raw[:kind].presence,
        available: raw[:availability].nil? ? nil : ActiveModel::Type::Boolean.new.cast(raw[:availability]),
        organiser_name: raw.dig(:organiser, :name).presence,
        venue_name: venue_name,
        category: raw.dig(:categorization, :category_localized).presence ||
                  raw.dig(:categorization, :category).presence,
        minimum_price_cents: raw.dig(:minimum_price, :amount_in_cents),
        currency: raw.dig(:minimum_price, :currency).presence
      }
    end

    def starts_at
      parse_time(raw[:startdate])
    end

    def ends_at
      parse_time(raw[:enddate])
    end

    private

    def parse_time(value)
      return nil if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def venue_name
      raw.dig(:location, :location_name).presence ||
        raw.dig(:location, :address_line).presence
    end
  end
end
