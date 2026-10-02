# frozen_string_literal: true

class EventsController < ApplicationController
  PER_PAGE = 50

  def index
    @events = Catalog::Event.upcoming.by_start_date.limit(PER_PAGE)
  end
end
