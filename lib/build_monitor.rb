# frozen_string_literal: true

require_relative 'loggers'
require_relative 'led_monitor'
require_relative 'build_fetcher'

# Use LEDs to monitor the last build status.
class BuildMonitor
  def initialize(project_id, api_token, branch, interval:, **options)
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
    @build_fetcher = options.fetch(:build_fetcher) do
      BuildFetcher.new project_id, api_token, branch, logger: @logger
    end

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


