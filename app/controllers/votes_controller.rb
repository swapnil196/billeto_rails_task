# frozen_string_literal: true

class VotesController < ApplicationController
  before_action :authenticate!

  def create
    command_bus.call(
      Voting::CastVote.new(
        event_tid: params[:event_tid],
        user_id: current_user_id,
        direction: params[:direction]
      )
    )

    redirect_back fallback_location: root_path, status: :see_other
  rescue Command::Invalid, ActiveRecord::RecordInvalid => exception
    Rails.logger.warn("[voting] refused vote: #{exception.message}")

    redirect_back fallback_location: root_path,
                  alert: "That vote could not be recorded.",
                  status: :see_other
  end
end
