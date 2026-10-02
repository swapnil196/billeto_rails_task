# frozen_string_literal: true

class EventsController < ApplicationController
  PER_PAGE = 50

  def index
    @events = Catalog::Event.upcoming.by_start_date.limit(PER_PAGE).to_a

    @tallies = tallies_for(@events)
    @my_votes = my_votes_for(@events)
  end

  private

  def tallies_for(events)
    ReadModels::EventVoteTally::Count
      .where(event_tid: events.map(&:tid))
      .index_by(&:event_tid)
  end

  def my_votes_for(events)
    return {} unless signed_in?

    Voting::Ballot
      .where(user_id: current_user_id, event_tid: events.map(&:tid))
      .index_by(&:event_tid)
  end
end
