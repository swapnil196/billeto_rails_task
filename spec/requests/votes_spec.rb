require "rails_helper"

RSpec.describe "Voting", type: :request do
  let(:event) { create(:catalog_event) }

  def sign_in(user_id = "user_abc")
    post dev_session_path, params: { user_id: user_id }
  end

  def vote(direction, tid: event.tid)
    post event_vote_path(event_tid: tid, direction: direction)
  end

  describe "when signed out" do
    it "refuses the vote" do
      vote("up")

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/sign in/i)
    end

    it "records nothing" do
      expect { vote("up") }.not_to change(Voting::Ballot, :count)
    end

    it "publishes nothing" do
      expect { vote("up") }
        .not_to change { Rails.configuration.event_store.read.count }
    end

    it "shows counts but no voting controls" do
      event # the listing needs something on it

      get root_path

      expect(response.body).to include("vote__btn--readonly")
      expect(response.body).not_to include("vote__btn--on")
    end
  end

  describe "when signed in" do
    before { sign_in }

    it "records the vote" do
      expect { vote("up") }.to change(Voting::Ballot, :count).by(1)
    end

    it "publishes the fact against the signed-in user" do
      vote("up")

      fact = Rails.configuration.event_store.read.stream("Voting$votes").last
      expect(fact).to be_a(Voting::EventUpvoted)
      expect(fact.data[:user_id]).to eq("user_abc")
    end

    it "sends the voter back where they came from" do
      vote("up")

      expect(response).to have_http_status(:see_other)
    end

    # show_exceptions is :rescuable in test, so an unroutable path is rendered
    # as a 404 rather than raised.
    it "refuses a direction the route does not allow" do
      post "/events/#{event.tid}/votes/sideways"

      expect(response).to have_http_status(:not_found)
    end

    it "attributes votes to whoever is signed in" do
      vote("up")
      sign_in("user_two")
      vote("up")

      expect(Voting::Ballot.pluck(:user_id)).to match_array(%w[user_abc user_two])
    end
  end

  describe "the listing once votes are counted" do
    before do
      sign_in
      perform_enqueued_jobs { vote("up") }
    end

    it "shows the tally" do
      get root_path

      expect(response.body).to match(/data-role="ups">\s*1\s*</)
    end

    it "marks the direction this visitor chose" do
      get root_path

      expect(response.body).to include("vote__btn--on")
    end

    it "shows the count to a signed-out visitor too" do
      delete dev_session_path

      get root_path

      expect(response.body).to match(/data-role="ups">\s*1\s*</)
    end
  end
end
