require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Required rather than autoloaded: the middleware stack is built before
# Zeitwerk is set up, and Rails does not constantize middleware named by
# string. lib/middleware is excluded from autoloading for the same reason.
require_relative "../lib/middleware/clerk_test_middleware"

# The gem's Railtie would insert Clerk::Rack::Middleware unconditionally. We
# need to swap it for a stand-in under test, so the insertion is done here
# instead -- explicitly, and in one readable place.
ENV["CLERK_SKIP_RAILTIE"] = "1"

module BillettoEvents
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Keyed off Rails.env rather than config.x, because the middleware stack is
    # built before the environment files are loaded.
    config.middleware.use(
      Rails.env.test? ? ClerkTestMiddleware : Clerk::Rack::Middleware
    )

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
