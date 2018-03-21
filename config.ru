require 'rubygems'
require 'bundler'
Bundler.setup

run ->(env) { [200, {"Content-Type" => "text/html"}, ["OK"]] }
