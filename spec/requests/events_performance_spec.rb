require "rails_helper"

# The listing reads a tally table rather than the event log. These pin down
# the thing that makes that worth doing: the page costs the same whether it
# shows three events or fifty, and whether those events have two votes or two
# thousand.
RSpec.describe "Events listing performance", type: :request do
  def sign_in(user_id = "user_abc")
    post dev_session_path, params: { user_id: user_id }
  end

  def vote(event, user_id:, direction: "up")
    perform_enqueued_jobs do
      Rails.configuration.command_bus.call(
        Voting::CastVote.new(event_tid: event.tid, user_id: user_id, direction: direction)
      )
    end
  end

  it "costs the same number of queries however many events are listed" do
    create_list(:catalog_event, 3)
    few = count_queries { get root_path }.size

    create_list(:catalog_event, 20)
    many = count_queries { get root_path }.size

    expect(many).to eq(few)
  end

  it "costs the same number of queries however many votes exist" do
    events = create_list(:catalog_event, 5)
    before = count_queries { get root_path }.size

    events.each do |event|
      10.times { |n| vote(event, user_id: "user_#{n}") }
    end

    expect(count_queries { get root_path }.size).to eq(before)
  end

  it "reads the tally table and never the event log" do
    create_list(:catalog_event, 3)

    sql = count_queries { get root_path }

    expect(sql.any? { |query| query.include?("event_vote_tallies") }).to be(true)
    expect(sql.none? { |query| query.include?("event_store_events") }).to be(true)
  end

  it "adds one query for a signed-in visitor, to mark their own votes" do
    create_list(:catalog_event, 3)
    signed_out = count_queries { get root_path }.size

    sign_in
    signed_in = count_queries { get root_path }.size

    expect(signed_in).to eq(signed_out + 1)
  end
end
