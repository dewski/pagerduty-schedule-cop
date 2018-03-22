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

          puts "[#{@name}][#{layer["name"]}] #{added.length} users added, #{removed.length} users removed, #{offboarded.length} users offboarded."

          offboarded.each do |pagerduty_id|
            index = previous_schedule_users.find_index { |key, _| pagerduty_id == key }
            username = previous_schedule_users[pagerduty_id]
            previous_schedule_users_array = Array(previous_schedule_users)


            # The person removed was in the front of the rotation, there wasn't
            # anyone before them.
            previous_username = unless index.zero? && previous_schedule_users_array.length == 2
              previous_schedule_users_array[index - 1]&.last
            end

            next_username = previous_schedule_users_array[index + 1]&.last

            issue = create_issue(
              username: username,
              schedule_name: schedule_name,
              position: index,
              previous_username: previous_username,
              next_username: next_username,
            )

            if issue
              puts "[#{@name}][#{layer["name"]}] Created issue for #{username} at #{issue[:html_url]}."
            else
              puts "[#{@name}][#{layer["name"]}] Could not create issue for #{pagerduty_id} at #{index}."
            end
          end
        end

        store(current_users, layer: layer["id"])
      end
    end

    private

    def create_issue(username:, schedule_name:, position:, previous_username: nil, next_username: nil)
      title = "#{username} was removed from #{schedule_name}"
      body = case
      when previous_username && next_username
        <<~BODY
        #{username} was removed at position #{position} in #{schedule_name}.

        Their spot in the rotation was in between #{previous_username} and #{next_username}.
        BODY
      when previous_username
        <<~BODY
        #{username} was removed at the #{position} position in #{schedule_name}.

        Their spot in the rotation was after #{previous_username}.
        BODY
      when next_username
        <<~BODY
        #{username} was removed at the #{position} position in #{schedule_name}.

        Their spot in the rotation was before #{next_username}.
        BODY
      else
        "#{username} was removed at the #{position} position in #{schedule_name}."
      end

      ScheduleCop.octokit.create_issue(@github_repository, title, body)
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
