# Subscriptions live on the event store client, which is a process-wide
# singleton. A spec that subscribes a handler would otherwise leak that
# subscription into every example that runs after it, and the handler would
# fire once per leaked subscription.
#
# Tag an example `:isolated_event_store` to give it a client of its own.
RSpec.configure do |config|
  config.before(:each, :isolated_event_store) do
    allow(Rails.configuration).to receive(:event_store).and_return(ApplicationEventStore.build)
  end
end
