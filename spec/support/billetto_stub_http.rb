# frozen_string_literal: true

class BillettoStubHttp
  attr_reader :requests

  def initialize(responses)
    @responses = responses
    @requests = []
  end

  def get(url, headers: {})
    @requests << { url: url, headers: headers }

    @responses.fetch(url) { raise "BillettoStubHttp has no response for #{url}" }
  end

  def urls
    requests.map { |request| request[:url] }
  end

  def self.json(body, status: 200)
    Billetto::Http::Response.new(status: status, body: JSON.dump(body))
  end

  def self.raw(body, status: 200)
    Billetto::Http::Response.new(status: status, body: body)
  end
end
