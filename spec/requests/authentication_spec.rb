require "rails_helper"

# Authentication now runs in Clerk's Rack middleware, so it can only be
# exercised from a request spec -- a controller spec bypasses the middleware
# stack entirely and would never see a session at all.
RSpec.describe "Authentication", type: :request do
  let(:event) { create(:catalog_event) }

  def sign_in_with(token)
    post dev_session_path, params: { user_id: token }
  end

  describe "identifying the visitor" do
    it "is anonymous with no session" do
      get root_path

      expect(response.body).to include("Sign in as")
      expect(response.body).not_to include("Signed in as")
    end

    it "resolves a session to a Clerk user id" do
      sign_in_with("user_abc")

      get root_path

      expect(response.body).to include("Signed in as")
      expect(response.body).to include("user_abc")
    end

    it "treats a session Clerk refuses as simply not signed in" do
      sign_in_with("expired")

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Signed in as")
    end

    # Set directly rather than through the dev route, which deliberately
    # invents an id when given none.
    it "treats an empty session cookie as not signed in" do
      cookies[ClerkTestMiddleware::COOKIE] = ""

      get root_path

      expect(response.body).not_to include("Signed in as")
    end
  end

  describe "guarding an action" do
    it "lets a signed-in visitor through" do
      sign_in_with("user_abc")

      expect {
        post event_vote_path(event_tid: event.tid, direction: "up")
      }.to change(Voting::Ballot, :count).by(1)
    end

    it "turns an anonymous visitor away" do
      post event_vote_path(event_tid: event.tid, direction: "up")

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/sign in/i)
    end

    it "does not perform the action for an anonymous visitor" do
      expect {
        post event_vote_path(event_tid: event.tid, direction: "up")
      }.not_to change(Voting::Ballot, :count)
    end

    it "turns away a visitor whose session Clerk refuses" do
      sign_in_with("expired")

      expect {
        post event_vote_path(event_tid: event.tid, direction: "up")
      }.not_to change(Voting::Ballot, :count)
    end

    it "answers a non-HTML request with 401 rather than a redirect" do
      post event_vote_path(event_tid: event.tid, direction: "up"), as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
