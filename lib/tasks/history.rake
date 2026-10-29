# frozen_string_literal: true

namespace :voting do
  desc "Print a stream's history (EVENT_TID=evt_… or USER=user_… or STREAM=…)"
  task history: :environment do
    stream =
      if ENV["STREAM"].present?      then ENV["STREAM"]
      elsif ENV["EVENT_TID"].present? then "Event$#{ENV['EVENT_TID']}"
      elsif ENV["USER"].present?      then "User$#{ENV['USER']}"
      else "Voting$votes"
      end

    facts = Rails.configuration.event_store.read.stream(stream).to_a

    puts
    puts "  #{stream}  —  #{facts.size} fact#{'s' unless facts.size == 1}"
    puts "  #{'─' * 96}"

    if facts.empty?
      puts "  (nothing here yet)"
    else
      facts.each_with_index do |fact, i|
        data = fact.data.map { |k, v| "#{k}=#{v}" }.join("  ")
        puts format("  %3d  %s  %-22s  %s", i + 1,
                    fact.timestamp.strftime("%d %b %H:%M:%S"),
                    fact.class.name.demodulize,
                    data)
        puts format("       correlation=%s  causation=%s",
                    fact.metadata[:correlation_id] || "—",
                    fact.metadata[:causation_id] || "—")
      end
    end

    puts
    puts "  Browse it all at http://localhost:3000/res"
    puts
  end
end
