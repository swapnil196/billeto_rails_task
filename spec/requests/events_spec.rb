require "rails_helper"

RSpec.describe "Events listing", type: :request do
  def escaped(text) = ERB::Util.html_escape(text)

  it "is the root page" do
    get root_path

    expect(response).to have_http_status(:ok)
  end

  it "shows the title, date, image and description the brief asks for" do
    create(
      :catalog_event,
      title: "The Candlelight Club's Halloween Ball",
      description: "A Halloween special from London's speakeasy party.",
      image_url: "https://billetto.imgix.net/abc?w=1200",
      starts_at: 3.days.from_now.change(hour: 19, min: 0, sec: 0)
    )

    get root_path

    expect(response.body).to include(escaped("The Candlelight Club's Halloween Ball"))
    expect(response.body).to include("A Halloween special")
    expect(response.body).to include("https://billetto.imgix.net/abc?w=1200")
    expect(response.body).to include(3.days.from_now.strftime("%-d %b %Y"))
  end

  it "orders events by when they start" do
    create(:catalog_event, title: "Later", starts_at: 3.weeks.from_now)
    create(:catalog_event, title: "Sooner", starts_at: 1.week.from_now)

    get root_path

    expect(response.body.index("Sooner")).to be < response.body.index("Later")
  end

  it "leaves out events that have already started" do
    create(:catalog_event, :past, title: "Last month's thing")
    create(:catalog_event, title: "Next month's thing")

    get root_path

    expect(response.body).not_to include(escaped("Last month's thing"))
    expect(response.body).to include(escaped("Next month's thing"))
  end

  it "explains how to populate an empty catalogue" do
    get root_path

    expect(response.body).to include("catalog:import")
  end

  it "renders an event with no image or description" do
    create(:catalog_event, title: "Bare bones", image_url: nil, description: nil)

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Bare bones")
  end
end
