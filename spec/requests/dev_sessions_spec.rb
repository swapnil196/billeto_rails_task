require "rails_helper"

# The dev sign-in seam exists so specs can exercise everything downstream of
# the session cookie without driving Clerk's own hosted screens.
RSpec.describe "Dev sessions", type: :request do
  it "signs a given user in" do
    post dev_session_path, params: { user_id: "user_abc" }

    expect(response).to have_http_status(:see_other)
    expect(cookies[ClerkTestMiddleware::COOKIE]).to eq("user_abc")
  end

  it "invents a user id when none is given" do
    post dev_session_path

    expect(cookies[ClerkTestMiddleware::COOKIE]).to match(/\Auser_[0-9a-f]+\z/)
  end

  it "signs out again" do
    post dev_session_path, params: { user_id: "user_abc" }

    delete dev_session_path

    expect(cookies[ClerkTestMiddleware::COOKIE]).to be_blank
  end
end
