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
  # RecordNotUnique belongs here as well as RecordInvalid. The command
  # serialises voters with an advisory lock, so a collision should not reach
  # us -- but if one ever does, a duplicate click is not worth a 500.
  rescue Command::Invalid,
         ActiveRecord::RecordInvalid,
         ActiveRecord::RecordNotUnique => exception
    Rails.logger.warn("[voting] refused vote: #{exception.message}")

    redirect_back fallback_location: root_path,
                  alert: "That vote could not be recorded.",
                  status: :see_other
  end
end
