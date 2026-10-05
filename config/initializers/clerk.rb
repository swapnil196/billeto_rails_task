# frozen_string_literal: true

Rails.application.config.to_prepare do
  credentials = Rails.application.credentials

  publishable_key =
    ENV["CLERK_PUBLISHABLE_KEY"].presence ||
    credentials.dig(:clerk, :publishable_key)

  secret_key =
    ENV["CLERK_SECRET_KEY"].presence ||
    credentials.dig(:clerk, :secret_key)

  Clerk.configure do |config|
    config.publishable_key = publishable_key if publishable_key.present?
    config.secret_key = secret_key if secret_key.present?
  end

  # Handy in views for mounting Clerk's own components.
  Rails.configuration.x.clerk.publishable_key = publishable_key
  Rails.configuration.x.clerk.frontend_api =
    ENV["CLERK_FRONTEND_API"].presence ||
    credentials.dig(:clerk, :frontend_api)
end
