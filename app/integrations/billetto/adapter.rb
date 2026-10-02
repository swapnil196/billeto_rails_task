# frozen_string_literal: true

module Billetto
  class Adapter
    DEFAULT_BASE_URL = "https://billetto.co.uk"
    EVENTS_PATH = "/api/v3/public/events"

    DEFAULT_PAGE_SIZE = 50

    MAX_PAGES = 500

    def initialize(api_keypair:, base_url: DEFAULT_BASE_URL, page_size: DEFAULT_PAGE_SIZE, http: HttpClient.new)
      if api_keypair.blank?
        raise ConfigurationError, "Billetto API keypair is missing"
      end

      @api_keypair = api_keypair
      @base_url = base_url.to_s.chomp("/")
      @page_size = page_size
      @http = http
    end

    def each_public_event(limit: nil)
      return enum_for(:each_public_event, limit: limit) unless block_given?

      url = first_page_url
      yielded = 0
      pages = 0

      while url && pages < MAX_PAGES
        body = fetch(url)

        Array(body["data"]).each do |raw|
          yield EventPayload.new(raw)
          yielded += 1
          return if limit && yielded >= limit
        end

        pages += 1
        url = body["has_more"] ? body["next_url"].presence : nil
      end
    end

    private

    def first_page_url(page_size: @page_size)
      "#{@base_url}#{EVENTS_PATH}?limit=#{page_size}"
    end

    def fetch(url)
      response = get(url)

      raise AuthenticationFailed, "Billetto rejected the credentials" if response.status == 401
      raise RequestFailed, "Billetto returned #{response.status} for #{url}" unless response.success?

      body = parse(response.body)
      raise_if_error_envelope(body)
      body
    end

    # The shared transport raises one error for every network failure; naming
    # it in Billetto's own vocabulary is this layer's job.
    def get(url)
      @http.get(url, headers: {
        "Api-Keypair" => @api_keypair,
        "Accept" => "application/json"
      })
    rescue HttpClient::TransportError => exception
      raise RequestFailed, exception.message
    end

    def parse(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError => exception
      raise RequestFailed, "Billetto returned an unreadable body: #{exception.message}"
    end

    def raise_if_error_envelope(body)
      error = body.is_a?(Hash) ? body["error"] : nil
      return if error.blank?

      message = error.is_a?(Hash) ? error["message"] : error.to_s

      if error.is_a?(Hash) && error["type"].to_s == "authentication_error"
        raise AuthenticationFailed, "Billetto: #{message}"
      end

      raise RequestFailed, "Billetto: #{message}"
    end
  end
end
