#!/usr/bin/env ruby

# Suppress all warnings
$VERBOSE = nil

require_relative 'lib/build_monitor'
require_relative 'lib/utils'
require 'dotenv'
require 'yaml'

Dotenv.load

api_token = ENV.fetch('GITLAB_API_PRIVATE_TOKEN')
interval = ARGV.shift || 60

projects = load_projects 'projects.yml'

monitor = MultiMonitor.new projects, api_token, interval: interval.to_i
monitor.start
