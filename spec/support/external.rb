# Specs tagged :external reach a real third-party service over the network.
#
# They are excluded by default so the suite stays runnable offline and in CI
# without credentials, and so a vendor's outage never looks like a bug in this
# codebase. Run them deliberately:
#
#   bundle exec rspec --tag external
RSpec.configure do |config|
  config.filter_run_excluding(:external) unless ENV["RUN_EXTERNAL_SPECS"]
end
