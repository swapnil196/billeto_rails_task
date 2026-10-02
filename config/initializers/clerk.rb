# frozen_string_literal: true

Rails.configuration.to_prepare do
  Rails.configuration.clerk_verifier =
    if Rails.configuration.x.clerk.use_fake_verifier
      Clerk::FakeVerifier.new
    else
      jwks_url =
        ENV["CLERK_JWKS_URL"].presence ||
        Rails.application.credentials.dig(:clerk, :jwks_url)

      if jwks_url.present?
        Clerk::SessionVerifier.new(
          key_source: Clerk::JwksKeySource.new(jwks_url: jwks_url),
          authorized_parties: Array(
            ENV["CLERK_AUTHORIZED_PARTIES"]&.split(",") ||
            Rails.application.credentials.dig(:clerk, :authorized_parties)
          )
        )
      else
        Rails.logger.info("[clerk] no JWKS url configured; using the fake verifier")
        Clerk::FakeVerifier.new
      end
    end
end
