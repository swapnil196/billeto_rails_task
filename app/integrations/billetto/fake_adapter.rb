# frozen_string_literal: true

module Billetto
  # Stands in for Adapter in the test environment, and in development when no
  # credentials are configured.
  #
  # The fixture it reads is a real, unedited response from the live endpoint
  # (descriptions truncated), so specs exercise the same payload shape the
  # application meets in production. Preferring this over stubbing HTTP keeps
  # the tests pointed at a seam we own.
  class FakeAdapter
    DEFAULT_FIXTURE = "db/fixtures/billetto_public_events.json"

    def initialize(fixture_path: Rails.root.join(DEFAULT_FIXTURE), payloads: nil)
      @fixture_path = fixture_path
      @payloads = payloads
    end

    def each_public_event(limit: nil)
      return enum_for(:each_public_event, limit: limit) unless block_given?

      records = payloads
      records = records.first(limit) if limit

      records.each { |raw| yield EventPayload.new(raw) }
    end

    private

    def payloads
      @payloads ||= Array(document["data"])
    end

    def document
      @document ||= JSON.parse(File.read(@fixture_path))
    rescue Errno::ENOENT
      raise ConfigurationError, "Billetto fixture missing at #{@fixture_path}"
    end
  end
end
