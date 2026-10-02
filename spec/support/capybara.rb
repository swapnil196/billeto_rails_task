# System specs default to rack_test, which needs no browser and is fast enough
# for everything that does not depend on JavaScript. Tag an example with
# `js: true` to get a real headless Chrome instead.
# The vote buttons carry an arrow glyph and a number, so their accessible name
# comes from aria-label. Letting Capybara match on it means the specs select
# the same thing a screen reader would announce, rather than a CSS class.
Capybara.enable_aria_label = true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  end
end
