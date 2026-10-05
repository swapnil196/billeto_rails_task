require "rails_helper"

# The test environment deliberately runs the dev sign-in seam, so these drive
# the Clerk-configured branch directly rather than asserting on what the suite
# happens to be wired for.
RSpec.describe "Clerk-hosted sign-in pages", type: :request do
  before do
    allow(Rails.configuration.x.clerk).to receive(:dev_sign_in).and_return(nil)
  end

  it "serves a sign-in page with a mount point for Clerk's component" do
    get sign_in_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-clerk-mount="sign-in"')
  end

  it "serves a sign-up page with a mount point" do
    get sign_up_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('data-clerk-mount="sign-up"')
  end

  it "loads Clerk's script from the configured instance with the publishable key" do
    get sign_in_path

    expect(response.body).to include(Rails.configuration.x.clerk.frontend_api.to_s)
    expect(response.body).to include("clerk.browser.js")
    expect(response.body).to include(Rails.configuration.x.clerk.publishable_key.to_s)
  end

  it "offers sign in and sign up to an anonymous visitor" do
    create(:catalog_event)

    get root_path

    expect(response.body).to include(sign_in_path)
    expect(response.body).to include(sign_up_path)
  end

  it "mounts Clerk's user button for a signed-in visitor" do
    post dev_session_path, params: { user_id: "user_abc" }

    get root_path

    expect(response.body).to include('data-clerk-mount="user-button"')
  end

  it "never ships the secret key to the browser" do
    get sign_in_path

    expect(response.body).not_to include("sk_test")
    expect(response.body).not_to include(Rails.application.credentials.dig(:clerk, :secret_key).to_s)
  end

  context "when Clerk is not configured at all" do
    before do
      allow(Rails.configuration.x.clerk).to receive(:publishable_key).and_return(nil)
    end

    it "says so rather than rendering a broken sign-in" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Clerk is not configured")
    end

    it "emits no Clerk script" do
      get root_path

      expect(response.body).not_to include("clerk.browser.js")
    end
  end
end
