# frozen_string_literal: true

require_relative 'loggers'
require_relative 'led_monitor'
require_relative 'build_fetcher'

def multi_logger_to(filename)
  stdout_logger = Logger.new STDOUT
  file_logger = Logger.new filename, 'daily'
  stdout_logger.level = file_logger.level = Logger::INFO unless ENV['DEBUG']

  MultiLogger.new file_logger, stdout_logger
end

def build_fetcher_for(project_id, api_token, branch, logger)
    BuildFetcher.new project_id, api_token, branch, logger: @logger
end

def start_loop(monitor)
  trap('SIGINT') do
    monitor.close!
    puts 'Bye!'
    # TODO: use exit with at_exit signal handlers
    exit!
  end

  loop do
    yield
  end
end

def wait(seconds, logger)
  logger.info { "Next check in #{seconds} secs" }
  sleep seconds
end

# Use LEDs to monitor the last build status.
class BuildMonitor
  def initialize(project_id, api_token, branch, interval:, only_red_green: false, **options)
    @interval = interval.to_i
    @only_red_green = only_red_green

    @logger = options.fetch(:logger) { multi_logger_to 'monitor.log' }
    @monitor = options.fetch(:led_monitor) { LedMonitor.new logger: @logger }
    @build_fetcher = options.fetch(:build_fetcher) { build_fetcher_for project_id, api_token, branch, @logger }

    @status = 'success' # assume we are in a good state
    @error = false
  end

  def start
    start_loop(@monitor) do
      check_latest
      wait @interval, @logger
    end
  end

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
    return if pending? && @only_red_green

    @monitor.all_off
    @monitor.turn_on led

    if failed?
      @monitor.buzz if was_success?
      @logger.info { "Blame: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    elsif success? && was_failed?
      @monitor.rapid_buzz
      @logger.info { "Praise: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    end
  rescue BuildFetcher::ServerError, BuildFetcher::NetworkError
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
end

class MultiMonitor
  def initialize(projects, api_token, interval:, only_red_green: false, **options)
    @interval = interval
    @only_red_green = only_red_green

    @logger = options.fetch(:logger) { multi_logger_to 'multi-monitor.log' }
    @monitor = options.fetch(:led_monitor) { MultiLedMonitor.new logger: @logger }
    @projects = projects.map do |config|
      name, branch, pins = config.values_at :name, :branch, :pins
      state = {
        build_fetcher: build_fetcher_for(name, api_token, branch, logger: @logger),
        pins: pins,
        status: 'success',
        error: false
      }

      [ name, state ]
    end.to_h

    green_leds = @projects.values.map { |state| state[:pins][:green] }.flatten.uniq
    green_leds.each { |pin| @monitor.turn_on pin }
  end

  def start
    start_loop(@monitor) do
      @projects.keys.each do |name|
        check_latest name
        wait @interval, @logger
      end
    end
  end

  def check_latest(name)
    project = @projects[name]
    buzzer_pin = buzzer_of name
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
    return if pending?(name) && @only_red_green

    @monitor.all_off all_leds_of name
    @monitor.turn_on led_of name, led

    if failed? name
      @monitor.buzz buzzer_pin if was_success? name
      @logger.info { "#{name.light_blue}: Blame: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    elsif success?(name) && was_failed?(name)
      @monitor.rapid_buzz buzzer_pin
      @logger.info { "#{name.light_blue}: Praise: #{latest_build[:sha][0, 8].light_yellow} by #{latest_build[:user][:name].light_blue}" }
    end
  rescue BuildFetcher::ServerError, BuildFetcher::NetworkError
    @monitor.all_off all_leds_of name
    %i(yellow red).each { |color| @monitor.turn_on led_of name, color }
    @monitor.rapid_buzz buzzer_pin, count: 3, duration: 0.3 unless project[:error]
    project[:error] = true
  end

  def all_leds_of(name)
    @projects[name][:pins].select { |k, _| %i(red yellow green).include? k }
  end

  def led_of(name, color)
    all_leds_of(name)[color]
  end

  def buzzer_of(name)
    @projects[name][:pins][:buzz]
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
end
