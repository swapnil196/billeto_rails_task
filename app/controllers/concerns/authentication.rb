# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  # Clerk's frontend SDK writes the session JWT to this cookie.
  SESSION_COOKIE = "__session"

  included do
    helper_method :current_user_id, :signed_in?
  end

  private

  def clerk_session
    return @clerk_session if defined?(@clerk_session)

    @clerk_session = verified_session
  end

  def verified_session
    token = cookies[SESSION_COOKIE]
    return nil if token.blank?

    Rails.configuration.clerk_verifier.verify(token)
  rescue Clerk::VerificationFailed => exception
    Rails.logger.info("[clerk] rejected session token: #{exception.message}")
    nil
  end

  def current_user_id
    clerk_session&.user_id
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
