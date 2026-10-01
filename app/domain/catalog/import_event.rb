# frozen_string_literal: true

module Catalog
  class ImportEvent
    include Command::Executable

    Result = Struct.new(:outcome, :event) do
      def created? = outcome == :created
      def updated? = outcome == :updated
      def unchanged? = outcome == :unchanged
    end

    attribute :external_id, String
    attribute :payload_attributes

    validates :external_id, presence: true
    validate :payload_attributes_present

    def call
      event = Event.find_by(external_id: external_id)

      event ? refresh(event) : import
    end

    private

    def import
      event = Event.create!(
        payload_attributes.merge(
          external_id: external_id,
          payload_digest: digest
        )
      )

      event_store.publish(
        EventImported.strict(
          data: { tid: event.tid, external_id: event.external_id, title: event.title }
        )
      )

      Result.new(:created, event)
    end

    def refresh(event)
      return Result.new(:unchanged, event) if event.payload_digest == digest

      changed = changed_attributes_for(event)
      event.update!(payload_attributes.merge(payload_digest: digest))

      event_store.publish(
        EventUpdated.strict(
          data: {
            tid: event.tid,
            external_id: event.external_id,
            changed: changed
          }
        )
      )

      Result.new(:updated, event)
    end

    def changed_attributes_for(event)
      Event::DESCRIPTIVE_ATTRIBUTES.filter_map do |name|
        next unless payload_attributes.key?(name)
        next if event.public_send(name) == payload_attributes[name]

        name.to_s
      end
    end

    def digest
      @digest ||= Event.digest_for(payload_attributes)
    end

    def payload_attributes_present
      return if payload_attributes.is_a?(Hash) && payload_attributes.any?

      errors.add(:payload_attributes, "must be a hash of mapped attributes")
    end
  end
end
