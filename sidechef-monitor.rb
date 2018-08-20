#!/usr/bin/env ruby

# Suppress all warnings
$VERBOSE = nil

require_relative 'lib/build_monitor'
require 'dotenv'

Dotenv.load

api_token = ENV.fetch('GITLAB_API_PRIVATE_TOKEN')
interval = ARGV.shift || 60

projects = [
  { name: 'sidechef/sidechef3',      branch: 'develop',   leds: { red: 9, green: 10, yellow: 11 } },
  { name: 'sidechef/SideChef_iOS',   branch: 'master',    leds: { red: 6, green: 7,  yellow: 8 } },
  { name: 'sidechef/client-android', branch: 'developer', leds: { red: 3, green: 4,  yellow: 5 } },
]

monitor = MultiMonitor.new projects, api_token, interval: interval
monitor.start
