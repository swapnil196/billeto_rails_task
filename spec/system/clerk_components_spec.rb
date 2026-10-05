require "rails_helper"

# Drives Clerk's own sign-in and sign-up components in a real browser against
# the configured Clerk instance.
#
# Tagged :external because it loads JavaScript from Clerk and talks to their
# API, so it is excluded from the default run.
#
# It stops short of completing a registration. Clerk sends a verification code
# to a real address, and automating that needs Clerk's testing tokens plus a
# live instance -- which would put a secret key and a network dependency into
# every CI run. What is proved here is the part this codebase owns: that our
# pages mount Clerk's components, and that Clerk renders a working form into
# them from our instance.
RSpec.describe "Clerk components", :js, :external, type: :system do
  before do
    # The test environment runs the dev sign-in seam; this exercises the branch
    # production uses instead.
    allow(Rails.configuration.x.clerk).to receive(:dev_sign_in).and_return(nil)
  end

  it "renders Clerk's sign-in form into our mount point" do
    visit sign_in_path

    expect(page).to have_css('[data-clerk-mount="sign-in"]')
    expect(page).to have_field("Email address", wait: 15)
    expect(page).to have_content(/secured by/i)
  end

  it "renders Clerk's sign-up form into our mount point" do
    visit sign_up_path

    expect(page).to have_css('[data-clerk-mount="sign-up"]')
    expect(page).to have_field("Email address", wait: 15)
  end

  # Asserting on Clerk's validation messages would be testing their product,
  # and their copy changes. What matters here is that the component is live
  # rather than a dead shell: it accepts input and offers its own controls.
  it "mounts a component that is actually interactive" do
    visit sign_in_path

    fill_in "Email address", with: "someone@example.com"

    expect(page).to have_field("Email address", with: "someone@example.com")
    expect(page).to have_button("Continue")
  end

  it "lets a visitor move between sign in and sign up" do
    visit sign_in_path

    expect(page).to have_link("Create one")
    click_link "Create one"

    expect(page).to have_css('[data-clerk-mount="sign-up"]')
  end

  it "never exposes the secret key to the page" do
    visit sign_in_path

    expect(page.html).not_to include("sk_test")
  end
end
