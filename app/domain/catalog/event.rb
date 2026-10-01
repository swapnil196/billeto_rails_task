# frozen_string_literal: true

module Catalog
  class Event < ApplicationRecord
    include EventStoreInjector
    include HasTypeid

    self.table_name = "events"

    has_typeid :evt

    DESCRIPTIVE_ATTRIBUTES = %i[
      title description image_url event_url starts_at ends_at
      state kind available organiser_name venue_name category
      minimum_price_cents currency
    ].freeze

    validates :external_id, presence: true, uniqueness: true
    validates :tid, uniqueness: true, allow_nil: true
    validates :title, presence: true
    validates :starts_at, presence: true
    validate :ends_at_after_starts_at

    scope :by_start_date, -> { order(:starts_at, :id) }
    scope :upcoming, -> { where(starts_at: Time.current..) }

    def self.digest_for(attributes)
      normalised =
        DESCRIPTIVE_ATTRIBUTES.index_with do |key|
          value = attributes[key]
          value.respond_to?(:utc) ? value.utc.iso8601 : value
        end

      Digest::SHA256.hexdigest(JSON.generate(normalised))
    end

    private

    def ends_at_after_starts_at
      return if ends_at.blank? || starts_at.blank?
      return if ends_at >= starts_at

      errors.add(:ends_at, "must not be before the start time")
    end
  end
end
