# frozen_string_literal: true

# Rails 7.2 no longer requires net/http for us.
require "net/http"

# A minimal HTTP transport shared by the integrations.
#
# Transport is infrastructure, so it lives here rather than inside any one
# integration. Error *semantics* are not infrastructure: this raises a single
# TransportError, and each integration translates that into a failure its own
# callers understand. That keeps the anti-corruption boundary intact while
# there is only one place that knows how to make a request.
class HttpClient
  TransportError = Class.new(StandardError)

  Response = Struct.new(:status, :body, keyword_init: true) do
    def success?
      status.between?(200, 299)
    end
  end

  RETRIABLE_ERRORS = [
    Timeout::Error,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::EHOSTUNREACH,
    SocketError,
    OpenSSL::SSL::SSLError,
    IOError
  ].freeze

  def initialize(open_timeout: 5, read_timeout: 15)
    @open_timeout = open_timeout
    @read_timeout = read_timeout
  end

  def get(url, headers: {})
    uri = URI.parse(url)
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: @open_timeout,
      read_timeout: @read_timeout
    ) { |http| http.request(request) }

    Response.new(status: response.code.to_i, body: response.body)
  rescue *RETRIABLE_ERRORS => exception
    raise TransportError, "GET #{url} failed: #{exception.class}: #{exception.message}"
  end
end
