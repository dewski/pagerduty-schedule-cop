require 'pp'

module ScheduleCop
  class Schedule
    SCHEDULES = YAML.load_file(File.expand_path("../../../config/schedules.yml", __FILE__))

    def self.all
      SCHEDULES.collect do |name, config|
        Schedule.new(name, config["pagerduty_schedule_id"], config["github_repository"])
      end
    end

    def self.process!
      remote_users = ScheduleCop::User.all

      all.each do |schedule|
        schedule.process(remote_users)
      end
    end

    def initialize(name, pagerduty_id, github_repository)
      @name = name
      @pagerduty_id = pagerduty_id
      @github_repository = github_repository
    end

    def process(users)
      schedule_name = pagerduty_schedule["name"]
      pagerduty_schedule["schedule_layers"].each do |layer|
        layer_users = layer["users"].collect { |user| user["user"] }
        current_users = ScheduleCop::User.from_response(layer_users)
        previous_schedule_users = schedule_users(layer: layer["id"])

        # There are no users stored in Redis.
        if previous_schedule_users.empty?
          puts "[#{@name}][#{layer["name"]}] No users stored yet for #{@name}, storing #{users.length} users."
        else
          # Users that were added to the rotation.
          added = current_users.keys - previous_schedule_users.keys

          # Users that were removed from the rotation.
          removed = previous_schedule_users.keys - current_users.keys

          # Users that were removed from the rotation & entire instance, likely
          # offboarded.
          offboarded = removed - users.keys

          puts "[#{@name}][#{layer["name"]}] Adding #{added.length} users, removing #{removed.length} users, #{offboarded.length} users offboarded."

          offboarded.each do |pagerduty_id|
            index = previous_schedule_users.find_index { |key, _| pagerduty_id == key }
            if issue = create_issue(previous_schedule_users[pagerduty_id], schedule_name, index)
              puts "[#{@name}][#{layer["name"]}] Created issue for #{pagerduty_id} at #{issue[:html_url]}."
            else
              puts "[#{@name}][#{layer["name"]}] Could not create issue for #{pagerduty_id} at #{index}."
            end
          end
        end

        store(current_users, layer: layer["id"])
      end
    end

    private

    def create_issue(username, schedule_name, index)
      ScheduleCop.octokit.create_issue(@github_repository, "#{username} was removed from #{schedule_name}", "They were removed at the #{index} position. That is right after $USER and right before $USER.")
    rescue Octokit::NotFound => error
      puts error
    rescue StandardError => error
      puts error
    end

    # { "pagerduty_id" => "dewski" }
    def schedule_users(layer: nil)
      ScheduleCop.redis.hgetall(schedule_users_key(layer))
    end

    def schedule_users_key(layer = nil)
      "schedule-cop:schedule:#{@pagerduty_id}:users#{":layer:#{layer}" if layer}"
    end

    def store(users, layer: nil)
      ScheduleCop.redis.multi do
        ScheduleCop.redis.del(schedule_users_key(layer))
        users.each do |id, name|
          ScheduleCop.redis.hset(schedule_users_key(layer), id, name)
        end
      end
    end

    def pagerduty_schedule
      return @pagerduty_schedule if defined?(@pagerduty_schedule)
      @pagerduty_schedule = ScheduleCop.pagerduty.schedule(@pagerduty_id)["schedule"]
    end
  end
end
