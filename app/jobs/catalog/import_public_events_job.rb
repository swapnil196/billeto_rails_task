# frozen_string_literal: true

module Catalog
  # Walks Billetto's public events and sends one ImportEvent command per event.
  class ImportPublicEventsJob < ApplicationJob
    include CommandBusInjector

    queue_as :low

    retry_on Billetto::RequestFailed, wait: :polynomially_longer, attempts: 5
    discard_on Billetto::ConfigurationError
    discard_on Billetto::AuthenticationFailed

    def perform(limit: nil)
      report = { seen: 0, invalid: 0, failed: 0, created: 0, updated: 0, unchanged: 0 }

      adapter.each_public_event(limit: limit) do |payload|
        report[:seen] += 1

        next report[:invalid] += 1 unless valid?(payload)

        import(payload, report)
      end

      Rails.logger.info("[catalog] import finished #{report.inspect}")
      report
    end

    private

    def adapter
      Rails.configuration.billetto
    end

    def valid?(payload)
      return true if payload.valid?

      Rails.logger.warn("[catalog] skipping event #{payload.external_id.inspect}: #{payload.errors.join('; ')}")
      false
    end

    def import(payload, report)
      result = command_bus.call(
        ImportEvent.new(
          external_id: payload.external_id,
          payload_attributes: payload.to_attributes.except(:external_id)
        )
      )

      report[result.outcome] += 1
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, Command::Invalid => exception
      # One event the domain refuses should not cost us the rest of the run.
      Rails.logger.warn("[catalog] failed to import #{payload.external_id.inspect}: #{exception.message}")
      report[:failed] += 1
    end
  end
end
