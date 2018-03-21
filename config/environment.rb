require 'rubygems'
require 'bundler'
Bundler.require

require 'dotenv/load'

require_relative '../lib/pagerduty'
require_relative '../lib/schedule_cop'
