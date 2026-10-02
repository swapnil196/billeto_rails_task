require "rails_helper"

RSpec.describe Authentication, type: :controller do
  controller(ApplicationController) do
    def who
      render plain: signed_in? ? current_user_id : "anonymous"
    end

    def guarded
      authenticate!
      render plain: "allowed" unless performed?
    end
  end

  before do
    routes.draw do
      get "who" => "anonymous#who"
      post "guarded" => "anonymous#guarded"
    end
  end

  describe "identifying the visitor" do
    it "is anonymous with no cookie" do
      get :who

      expect(response.body).to eq("anonymous")
    end

    it "resolves the cookie to a Clerk user id" do
      request.cookies[Authentication::SESSION_COOKIE] = "user_abc"

      get :who

      expect(response.body).to eq("user_abc")
    end

    it "treats a token the verifier rejects as simply not signed in" do
      request.cookies[Authentication::SESSION_COOKIE] = "expired"

      get :who

      expect(response.body).to eq("anonymous")
      expect(response).to have_http_status(:ok)
    end

    it "treats a blank cookie as not signed in" do
      request.cookies[Authentication::SESSION_COOKIE] = ""

      get :who

      expect(response.body).to eq("anonymous")
    end

    it "verifies once per request" do
      request.cookies[Authentication::SESSION_COOKIE] = "user_abc"
      allow(Rails.configuration.clerk_verifier).to receive(:verify).and_call_original

      get :who

      expect(Rails.configuration.clerk_verifier).to have_received(:verify).once
    end
  end

  describe "guarding an action" do
    it "lets a signed-in visitor through" do
      request.cookies[Authentication::SESSION_COOKIE] = "user_abc"

      post :guarded

      expect(response.body).to eq("allowed")
    end

    it "turns an anonymous visitor away" do
      post :guarded

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/sign in/i)
    end

    it "does not run the action for an anonymous visitor" do
      post :guarded

      expect(response.body).not_to include("allowed")
    end

    it "answers a non-HTML request with 401 rather than a redirect" do
      post :guarded, format: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
