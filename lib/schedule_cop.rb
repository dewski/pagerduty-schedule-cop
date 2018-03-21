require_relative './pagerduty'

module ScheduleCop
  def self.pagerduty
    return @pagerduty if defined?(@pagerduty)
    @pagerduty = Pagerduty.new(ENV["PAGERDUTY_API_KEY"])
  end

  def self.redis
    return @redis if defined?(@redis)
    @redis = Redis.new(url: ENV["REDIS_URL"])
  end

  def self.octokit
    return @octokit if defined?(@octokit)
    @octokit = Octokit::Client.new(access_token: ENV["OCTOKIT_ACCESS_TOKEN"])
  end
end

require_relative './schedule_cop/schedule'
require_relative './schedule_cop/user'
