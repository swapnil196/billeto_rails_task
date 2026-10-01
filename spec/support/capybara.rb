# System specs default to rack_test, which needs no browser and is fast enough
# for everything that does not depend on JavaScript. Tag an example with
# `js: true` to get a real headless Chrome instead.
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  end
end
