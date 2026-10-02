# frozen_string_literal: true

namespace :voting do
  desc "Rebuild vote tallies from the event log (EVENT_TID=evt_... for one event)"
  task rebuild_tallies: :environment do
    event_tid = ENV["EVENT_TID"].presence

    puts "[voting] rebuilding #{event_tid || 'all'} tallies from the event log"

    report = ReadModels::RebuildEventVoteTallies.new.call(event_tid: event_tid) do |applied, total|
      print "\r[voting] #{applied}/#{total}" if (applied % 100).zero? || applied == total
    end

    puts
    puts "[voting] #{report.inspect}"
  end
end
