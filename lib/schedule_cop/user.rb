module ScheduleCop
  class User
    def self.all
      more = true
      users = []
      offset = 0

      while more
        puts "Making request to PagerDuty for users with offset #{offset}"
        response = ScheduleCop.pagerduty.users(offset: offset)
        users << response.fetch("users")
        more = response.fetch("more")
        offset = response.fetch("offset") + response.fetch("limit")
      end

      from_response(users.flatten)
    end

    def self.from_response(users)
      formatted_users = users.collect do |user|
        [user["id"], user["name"] || user["summary"]]
      end

      Hash[formatted_users]
    end
  end
end
