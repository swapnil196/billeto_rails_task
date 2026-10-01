# frozen_string_literal: true

namespace :catalog do
  desc "Import public events from Billetto (LIMIT=n for capping)"
  task import: :environment do
    limit = ENV["LIMIT"].presence&.to_i

    puts "[catalog] importing via #{Rails.configuration.billetto.class}#{limit ? " (limit #{limit})" : ''}"
    report = Catalog::ImportPublicEventsJob.perform_now(limit: limit)
    puts "[catalog] #{report.inspect}"
    puts "[catalog] events in catalogue: #{Catalog::Event.count}"
  end
end
