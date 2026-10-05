# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    include Clerk::Authenticatable

    helper_method :current_user_id, :signed_in?
  end

  private

  def current_user_id
    clerk&.user_id
  end

  def signed_in?
    current_user_id.present?
  end

  def authenticate!
    return if signed_in?

    respond_to do |format|
      format.html { redirect_to root_path, alert: "Please sign in to vote.", status: :see_other }
      format.any { head :unauthorized }
    end
  end
end
