FactoryBot.define do
  factory :catalog_event, class: "Catalog::Event" do
    sequence(:external_id) { |n| "20228#{n.to_s.rjust(2, '0')}" }
    sequence(:title) { |n| "An Evening of Something #{n}" }
    description { "A description of the event." }
    image_url { "https://billetto.imgix.net/example?w=1200" }
    event_url { "https://billetto.co.uk/e/example" }
    starts_at { 2.weeks.from_now.change(usec: 0) }
    ends_at { starts_at + 3.hours }
    state { "published" }
    kind { "regular" }
    available { true }
    organiser_name { "An Organiser" }
    venue_name { "A Venue" }
    category { "Music" }
    minimum_price_cents { 1500 }
    currency { "GBP" }

    trait :past do
      starts_at { 2.weeks.ago.change(usec: 0) }
    end
  end
end
