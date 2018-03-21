module ScheduleCop
  SCHEDULES = File.read(File.expand_path("../../config/schedules.yml", __FILE__))
end
