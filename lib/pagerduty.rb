require 'httparty'

class Pagerduty
  include HTTParty
  base_uri 'https://api.pagerduty.com'

  def initialize(token)
    @token = token
  end

  def users(offset: 0)
    users = api('/users', offset: offset)
  end

  def schedule(id)
    schedile = api("/schedules/#{id}")
  end

  private
    def api(path, query = {})
      self.class.get(path, query: query, headers: {
        'Authorization' => "Token token=#{@token}",
        'Accept' => 'application/vnd.pagerduty+json;version=2',
      })
    end
end
