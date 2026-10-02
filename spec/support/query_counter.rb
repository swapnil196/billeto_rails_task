# Counts the SQL the block issues, ignoring schema and transaction chatter.
module QueryCounter
  def count_queries
    queries = []

    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
      next if payload[:sql].start_with?("BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT", "RELEASE")

      queries << payload[:sql]
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end

RSpec.configure { |config| config.include QueryCounter }
