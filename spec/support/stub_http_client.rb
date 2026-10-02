# A stand-in for HttpClient.
#
# Passing a collaborator keeps the adapter specs honest without stubbing HTTP
# globally: the adapter is driven through the same seam the real transport
# plugs into, so the contract under test is one this codebase defines.
class StubHttpClient
  attr_reader :requests

  def initialize(responses)
    @responses = responses
    @requests = []
  end

  def get(url, headers: {})
    @requests << { url: url, headers: headers }

    @responses.fetch(url) { raise "StubHttpClient has no response for #{url}" }
  end

  def urls
    requests.map { |request| request[:url] }
  end

  def self.json(body, status: 200)
    HttpClient::Response.new(status: status, body: JSON.dump(body))
  end

  def self.raw(body, status: 200)
    HttpClient::Response.new(status: status, body: body)
  end
end
