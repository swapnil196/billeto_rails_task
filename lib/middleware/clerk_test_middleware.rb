# frozen_string_literal: true

# Stands in for Clerk::Rack::Middleware in the test environment.
#
# Clerk's middleware verifies a real session JWT against Clerk's keys, which a
# spec cannot produce without either shipping a secret key into CI or calling
# Clerk over the network from every example. This builds the same
# Clerk::Proxy the real middleware builds, from a cookie whose value is simply
# the user id -- so everything downstream, including Clerk::Authenticatable's
# `clerk` helper, runs exactly the code it runs in production.
#
# Only mounted where the application is configured to use it, which production
# never is.
class ClerkTestMiddleware
  COOKIE = "__session"
  PREFIX = "user_"

  # Sentinels standing in for a session Clerk refuses -- expired, tampered
  # with, signed by another instance. The real middleware tells none of those
  # apart to the application either: they all arrive as "not signed in".
  REJECTED = %w[expired invalid].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    token = ::Rack::Request.new(env).cookies[COOKIE].presence

    env["clerk.initialized"] = true
    env["clerk"] = Clerk::Proxy.new(
      session_claims: claims_for(token),
      session_token: token
    )

    @app.call(env)
  end

  private

  def claims_for(token)
    return nil if token.blank? || REJECTED.include?(token)

    { "sub" => normalise(token) }
  end

  # Lets a spec write `user_abc` or just `abc` and mean the same person.
  def normalise(token)
    token.start_with?(PREFIX) ? token : "#{PREFIX}#{token}"
  end
end
