# frozen_string_literal: true

# Hosts the pages Clerk's own sign-in and sign-up components mount into.
#
# There is no logic here and there should not be: Clerk owns the credential
# handling, the verification emails and the session. This application's only
# interest is the user id that comes back on the next request.
class SessionsController < ApplicationController
  def new; end

  def sign_up; end
end
