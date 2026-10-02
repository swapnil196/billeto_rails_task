require "rails_helper"

# The same journey as voting_spec.rb, but driven through real headless Chrome.
#
# rack_test is a Rack client, not a browser: it does not run JavaScript and it
# follows forms by hand. Turbo intercepts these form submissions in a real
# browser, so this is the only pass that proves the flow actually works for a
# person rather than for a Rack client.
#
# Tagged :js, which the Capybara support file maps to headless Chrome.
RSpec.describe "Voting in a real browser", :js, type: :system do
  let!(:event) { create(:catalog_event, title: "An Evening of Reasonable Expectations") }

  it "signs in, votes, sees the count, and signs out" do
    visit root_path
    expect(page).to have_content("An Evening of Reasonable Expectations")
    expect(page).to have_no_button("Like #{event.title}")

    fill_in "Sign in as", with: "user_demo"
    click_button "Sign in"
    expect(page).to have_content("Signed in as")

    # In a real browser click_button returns as soon as the click is
    # dispatched, so wrapping it in perform_enqueued_jobs can drain the queue
    # before the request has even enqueued the job. Wait for a change the
    # server made, then drain. rack_test hides this: its clicks are synchronous.
    click_button "Like #{event.title}"
    expect(page).to have_css(".vote__btn--on")
    perform_enqueued_jobs

    visit root_path
    within(".vote") { expect(page).to have_content("1") }

    click_button "Sign out"
    expect(page).to have_content("Sign in as")
    expect(page).to have_no_button("Like #{event.title}")
  end
end
