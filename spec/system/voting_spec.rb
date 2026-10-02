require "rails_helper"

# End to end through the browser: sign in, vote, see the count, sign out.
#
# These run on rack_test by default -- no browser process, fast enough to keep
# in the normal suite. The same flow is exercised in real headless Chrome in
# spec/system/voting_js_spec.rb.
RSpec.describe "Voting through the browser", type: :system do
  let!(:event) { create(:catalog_event, title: "An Evening of Reasonable Expectations") }

  def sign_in(as: "user_demo")
    fill_in "Sign in as", with: as
    click_button "Sign in"
  end

  def like(title = event.title)
    click_button "Like #{title}"
  end

  it "shows the event to a visitor who is not signed in" do
    visit root_path

    expect(page).to have_content("An Evening of Reasonable Expectations")
    expect(page).to have_content("What's on")
  end

  it "offers no voting controls until you sign in" do
    visit root_path

    expect(page).to have_no_button("Like #{event.title}")
  end

  it "turns away a vote attempted without signing in" do
    page.driver.post(event_vote_path(event_tid: event.tid, direction: "up"))

    expect(Voting::Ballot.count).to eq(0)
  end

  describe "the signed-in flow" do
    it "signs in" do
      visit root_path
      sign_in

      expect(page).to have_content("Signed in as")
      expect(page).to have_content("user_demo")
    end

    it "reveals the voting controls once signed in" do
      visit root_path
      sign_in

      expect(page).to have_button("Like #{event.title}")
    end

    it "records a vote and shows the count once the queue drains" do
      visit root_path
      sign_in

      perform_enqueued_jobs { like }
      visit root_path

      within(".vote") { expect(page).to have_content("1") }
    end

    it "marks the direction this visitor chose" do
      visit root_path
      sign_in
      perform_enqueued_jobs { like }
      visit root_path

      expect(page).to have_css(".vote__btn--on")
    end

    it "takes the vote back when the same button is pressed again" do
      visit root_path
      sign_in

      perform_enqueued_jobs { like }
      visit root_path
      perform_enqueued_jobs { like }
      visit root_path

      expect(page).to have_no_css(".vote__btn--on")
      expect(Voting::Ballot.count).to eq(0)
    end

    it "keeps the withdrawn vote in the log" do
      visit root_path
      sign_in
      perform_enqueued_jobs { like }
      visit root_path
      perform_enqueued_jobs { like }

      stream = Rails.configuration.event_store.read.stream("Voting$votes").to_a
      expect(stream.map(&:class)).to eq([ Voting::EventUpvoted, Voting::VoteWithdrawn ])
    end

    it "signs out again" do
      visit root_path
      sign_in
      click_button "Sign out"

      expect(page).to have_content("Sign in as")
      expect(page).to have_no_content("Signed in as")
    end

    it "hides the voting controls again after signing out" do
      visit root_path
      sign_in
      click_button "Sign out"

      expect(page).to have_no_button("Like #{event.title}")
    end

    it "keeps the count visible to a signed-out visitor" do
      visit root_path
      sign_in
      perform_enqueued_jobs { like }
      click_button "Sign out"

      within(".vote") { expect(page).to have_content("1") }
    end
  end
end
