#!/usr/bin/env ruby
# frozen_string_literal: true

require 'arduino_firmata'
require 'colorize'
require 'dotenv'
require 'json'
require 'logger'
require 'net/http'
require 'uri'

Dotenv.load

LOGGER_METHODS = %w(log debug info warn error fatal unknown).freeze

# Logger Multiplexer.
# https://stackoverflow.com/questions/6407141/how-can-i-have-ruby-logger-log-output-to-stdout-as-well-as-file
class MultiLogger
  def initialize(*targets)
    @targets = targets
  end

  LOGGER_METHODS.each do |m|
    define_method(m) do |*args, &blk|
      @targets.each { |t| t.public_send(m, *args, &blk) }
    end
  end
end

# Dummy logger
class DummyLogger
  LOGGER_METHODS.each do |m|
    define_method(m) do |*args, &blk|
      # noop
    end
  end
end

# Fetches build info from Gitlab API.
class BuildFetcher
  BASE_URI = 'https://gitlab.com/api/v4'

  class ServerError < StandardError; end
  class NetworkError < StandardError; end

  def initialize(project_id, api_token, logger: DummyLogger.new)
    @project_id = project_id
    @api_token = api_token
    @logger = logger
  end

  def latest_build(branch = 'develop')
    @logger.info { 'Fetching pipelines ...' }

    pipelines_url = "#{BASE_URI}/projects/#{@project_id}/pipelines"
    response = fetch pipelines_url
    pipelines = JSON.parse response.body, symbolize_names: true

    # returned build are already sorted
    latest = pipelines.find { |el| el[:ref] == branch }

    detail_url = "#{pipelines_url}/#{latest[:id]}"
    response = fetch detail_url
    last_build = JSON.parse response.body, symbolize_names: true
    @logger.debug { "Last build on #{branch}: #{last_build.inspect.light_yellow}" }

    last_build
  rescue SocketError, Timeout::Error => ex
    raise NetworkError, ex
  end

  private

    def fetch(url)
      uri = URI url
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new uri
        request.add_field 'PRIVATE-TOKEN', @api_token

        http.request request
      end
      @logger.debug { response }

      if response.code.to_i != 200
        @logger.debug { response.body.inspect.light_yellow }
        message = "#{response.message.red} (#{response.code.red}): #{response.body.underline}"
        raise ServerError, message
      end

      response
    end
end

# Controls LEDs on an Arduino board with Firmata.
class LedMonitor
  LEDS = {
    red: 9,
    green: 10,
    yellow: 11
  }.freeze

  BUZZER = 5

  def initialize(logger: DummyLogger.new)
    @logger = logger

    if block_given?
      @arduino = yield
    else
      #:nocov:
      @logger.debug { 'Connecting to arduino ...' }
      @arduino = ArduinoFirmata.connect
      # :nocov:
    end

    @logger.info { "Connected with Firmata version #{@arduino.version}" }
    LEDS.keys.each { |led| turn_on led }
  end

  def close
    @logger.debug { 'Closing Firmata connection' }
    @arduino.close
  end

  # :nocov:
  def close!
    # workaround for "log writing failed. can't be called from trap context"
    LEDS.values.each { |pin| @arduino.digital_write pin, false }
    sleep 0.1
    @arduino.close
  end
  # :nocov:

  def all_off
    @logger.debug { 'Turning off all leds' }
    LEDS.values.each { |pin| @arduino.digital_write pin, false }
  end

  def turn_on(led)
    @logger.debug { "Turning on #{led} led" }
    @arduino.digital_write LEDS[led], true
  end

  def buzz(duration = 0.5)
    @logger.debug { "Buzzing for #{duration} sec" }
    @arduino.digital_write BUZZER, true
    sleep duration
    @arduino.digital_write BUZZER, false
  end

  def rapid_buzz(count: 2, duration: 0.05)
    @logger.debug { "Buzzing #{count} times" }
    count.times do
      buzz duration
      sleep duration
    end
  end
end

# Use LEDs to monitor the last build status.
class BuildMonitor
  def initialize(project_id, api_token, interval:, **options)
    @interval = interval.to_i

    @logger = options.fetch(:logger) do
      # :nocov:
      stdout_logger = Logger.new STDOUT
      file_logger = Logger.new 'monitor.log', 'daily'
      stdout_logger.level = file_logger.level = Logger::INFO unless ENV['DEBUG']
      MultiLogger.new file_logger, stdout_logger
      # :nocov:
    end

    @monitor = options.fetch(:led_monitor) { LedMonitor.new logger: @logger }
    @build_fetcher = options.fetch(:build_fetcher) { BuildFetcher.new project_id, api_token, logger: @logger }

    @status = 'success' # assume we are in a good state
    @error = false
  end

  # :nocov:
  def start
    trap('SIGINT') do
      @monitor.close!
      puts 'Bye!'
      # TODO: use exit with at_exit signal handlers
      exit!
    end

    loop do
      check_latest
      wait @interval
    end
  end
  # :nocov:

  def check_latest
    latest_build = @build_fetcher.latest_build

    @error = false
    @prev_status = @status unless pending?
    @status = latest_build[:status]
    led = case @status
          when 'success' then :green
          when 'failed'  then :red
          else :yellow
          end

    @logger.info { "Build status is #{@status.colorize(led)}" }
    @monitor.all_off
    @monitor.turn_on led
    if failed?
      @monitor.buzz if was_success?
      @logger.info { "Blame: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    elsif success? && was_failed?
      @monitor.rapid_buzz
      @logger.info { "Praise: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    end
  rescue BuildFetcher::ServerError, BuildFetcher::NetworkError => ex
    @logger.error ex.message
    @monitor.all_off
    %i(yellow red).each { |ld| @monitor.turn_on ld }
    @monitor.rapid_buzz count: 3, duration: 0.3 unless @error
    @error = true
  end

  def failed?
    @status == 'failed'
  end

  def success?
    @status == 'success'
  end

  def pending?
    !%w(success failed).include? @status
  end

  def was_success?
    @prev_status == 'success'
  end

  def was_failed?
    @prev_status == 'failed'
  end

  # :nocov:
  def wait(seconds)
    @logger.info { "Next check in #{seconds} secs" }
    sleep seconds
  end
  # :nocov:
end

# :nocov:
if __FILE__ == $PROGRAM_NAME
  project_id = ENV.fetch('GITLAB_PROJECT_ID')
  api_token = ENV.fetch('GITLAB_API_PRIVATE_TOKEN')

  interval = ARGV.shift || 120
  monitor = BuildMonitor.new project_id, api_token, interval: interval
  monitor.start
end
# :nocov:
