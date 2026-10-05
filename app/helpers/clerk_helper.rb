# frozen_string_literal: true

# View helpers for mounting Clerk's own components.
#
# Clerk serves its JavaScript from your instance's own Frontend API host rather
# than a shared CDN, so the script urls are derived from configuration instead
# of hard-coded.
module ClerkHelper
  CLERK_JS_VERSION = 6
  CLERK_UI_VERSION = 1

  def clerk_configured?
    clerk_publishable_key.present? && clerk_frontend_api.present?
  end

  def clerk_publishable_key
    Rails.configuration.x.clerk.publishable_key
  end

  def clerk_frontend_api
    Rails.configuration.x.clerk.frontend_api
  end

  def clerk_js_url
    "#{clerk_frontend_api}/npm/@clerk/clerk-js@#{CLERK_JS_VERSION}/dist/clerk.browser.js"
  end

  def clerk_ui_url
    "#{clerk_frontend_api}/npm/@clerk/ui@#{CLERK_UI_VERSION}/dist/ui.browser.js"
  end

  # True where the application is wired to sign people in without Clerk, which
  # is the test environment only.
  def dev_sign_in?
    Rails.configuration.x.clerk.dev_sign_in.present?
  end
end
