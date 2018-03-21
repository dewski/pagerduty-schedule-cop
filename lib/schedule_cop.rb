require_relative './pagerduty'

module ScheduleCop
  SCHEDULES = File.read(File.expand_path("../../config/schedules.yml", __FILE__))

  def self.pagerduty
    return @pagerduty if defined?(@pagerduty)
    @pagerduty = Pagerduty.new(ENV["PAGERDUTY_API_TOKEN"])
  end
end
