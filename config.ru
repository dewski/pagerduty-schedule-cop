require_relative './config/environment'

run ->(env) { [200, {"Content-Type" => "text/html"}, ["OK"]] }
