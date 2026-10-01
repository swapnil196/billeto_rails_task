# frozen_string_literal: true

Rails.configuration.to_prepare do
  Rails.configuration.billetto =
    if Rails.configuration.x.billetto.use_fake_adapter
      Billetto::FakeAdapter.new
    else
      keypair =
        ENV["BILLETTO_API_KEYPAIR"].presence ||
        Rails.application.credentials.dig(:billetto, :api_keypair)

      if keypair.present?
        Billetto::Adapter.new(
          api_keypair: keypair,
          base_url:
            ENV["BILLETTO_BASE_URL"].presence ||
            Rails.application.credentials.dig(:billetto, :base_url) ||
            Billetto::Adapter::DEFAULT_BASE_URL
        )
      else
        Rails.logger.info("[billetto] no API keypair configured; using the fixture-backed fake adapter")
        Billetto::FakeAdapter.new
      end
    end
end
