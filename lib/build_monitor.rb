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

class MultiMonitor
  def initialize(projects, api_token, interval:, **options)
    @interval = interval

    # TODO: DRY
    @logger = options.fetch(:logger) do
      # :nocov:
      stdout_logger = Logger.new STDOUT
      file_logger = Logger.new 'multi-monitor.log', 'daily'
      stdout_logger.level = file_logger.level = Logger::INFO unless ENV['DEBUG']
      MultiLogger.new file_logger, stdout_logger
      # :nocov:
    end

    # XXX: this is shared
    @monitor = options.fetch(:led_monitor) { MultiLedMonitor.new logger: @logger }

    @projects = projects.map do |config|
      [
        config[:name],
        {
          build_fetcher: BuildFetcher.new(config[:name], api_token, config[:branch], logger: @logger),
          leds: config[:leds],
          status: 'success',
          error: false
        }
      ]
    end.to_h
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
      @projects.keys.each do |name|
        check_latest name
        wait @interval
      end
    end
  end
  # :nocov:

  def check_latest(name)
    project = @projects[name]
    latest_build = project[:build_fetcher].latest_build

    project[:error] = false
    project[:prev_status] = project[:status] unless pending? name
    project[:status] = latest_build[:status]
    led = case project[:status]
          when 'success' then :green
          when 'failed'  then :red
          else :yellow
          end

    @logger.info { "#{name.light_blue}: Build status is #{project[:status].colorize(led)}" }
    @monitor.all_off all_leds_of name
    @monitor.turn_on led_of name, led

    if failed? name
      @monitor.buzz if was_success? name
      @logger.info { "#{name.light_blue}: Blame: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    elsif success?(name) && was_failed?(name)
      @monitor.rapid_buzz
      @logger.info { "#{name.light_blue}: Praise: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    end
  rescue BuildFetcher::ServerError, BuildFetcher::NetworkError => ex
    @logger.error ex.message
    @monitor.all_off all_leds_of name
    %i(yellow red).each { |color| @monitor.turn_on led_of name, color }
    @monitor.rapid_buzz count: 3, duration: 0.3 unless project[:error]
    project[:error] = true
  end

  def all_leds_of(name)
    @projects[name][:leds]
  end

  def led_of(name, color)
    all_leds_of(name)[color]
  end

  def status_of(name)
    @projects[name][:status]
  end

  def prev_status_of(name)
    @projects[name][:prev_status]
  end

  def failed?(name)
    status_of(name) == 'failed'
  end

  def success?(name)
    status_of(name) == 'success'
  end

  def pending?(name)
    !%w(success failed).include? status_of(name)
  end

  def was_success?(name)
    prev_status_of(name) == 'success'
  end

  def was_failed?(name)
    prev_status_of(name) == 'failed'
  end

  # XXX: DRY
  # :nocov:
  def wait(seconds)
    @logger.info { "Next check in #{seconds} secs" }
    sleep seconds
  end
  # :nocov:
end
