# frozen_string_literal: true

class DevSessionsController < ApplicationController
  def create
    cookies[ClerkTestMiddleware::COOKIE] = {
      value: params[:user_id].presence || "user_#{SecureRandom.hex(4)}",
      httponly: true,
      same_site: :lax
    }

    redirect_back fallback_location: root_path, status: :see_other
  end

  def destroy
    cookies.delete(ClerkTestMiddleware::COOKIE)

    redirect_back fallback_location: root_path, status: :see_other
  end
end
