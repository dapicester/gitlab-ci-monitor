#!/usr/bin/env ruby

# Suppress all warnings
$VERBOSE = nil

require_relative 'lib/build_monitor'
require 'dotenv'

Dotenv.load

project_id = ENV.fetch('GITLAB_PROJECT_ID')
api_token = ENV.fetch('GITLAB_API_PRIVATE_TOKEN')
branch = 'develop'
interval = ARGV.shift || 120

monitor = BuildMonitor.new project_id, api_token, branch, interval: interval
monitor.start
