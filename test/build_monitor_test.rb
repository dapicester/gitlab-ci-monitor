require 'test_helper'
require_relative '../lib/build_monitor'

class BuildMonitorTest < Minitest::Test
  def setup
    @logger = DummyLogger.new
    @led_monitor = Minitest::Mock.new
    @build_fetcher = Minitest::Mock.new

    @subject = BuildMonitor.new 'project_id',
                                'api_token',
                                'develop',
                                interval: 120,
                                logger: @logger,
                                led_monitor: @led_monitor,
                                build_fetcher: @build_fetcher
  end

  def test_check_latest_success
    with_latest :success do
      expect_led :green
    end
  end

  def test_check_latest_pending
    refute @subject.instance_variable_get :@only_red_green
    with_latest :pending do
      expect_led :yellow
    end
  end

  def test_check_latest_pending_only_red_green
    # flip the flag value
    @subject.instance_variable_set :@only_red_green, true
    assert @subject.instance_variable_get :@only_red_green

    with_latest :pending do
      expect_led nil
    end
  end

  def test_check_latest_failed
    with_latest :failed do
      expect_led :red
      expect_buzz
    end

    with_latest :pending do
      expect_led :yellow
    end

    with_latest :failed do
      expect_led :red
      # no buzz this time, was already failed
    end

    with_latest :success do
      expect_led :green
      expect_rapid_buzz
    end
  end

  def test_check_latest_fetch_error
    [BuildFetcher::ServerError, BuildFetcher::NetworkError].each do |exception|
      with_latest -> { raise exception } do
        @led_monitor.expect :all_off, nil
        expect_rapid_buzz count: 3, duration: 0.3
        expect_led :yellow
        expect_led :red
      end
    end
  end

  private

  def get_build(status)
    {
      'id': 48,
      'status': status.to_s,
      'ref': 'develop',
      'sha': 'eb94b618fb5865b26e80fdd8ae531b7a63ad851a',
      'user': { 'name': 'John Doe' }
    }
  end

  def with_latest(status_or_callable)
    if status_or_callable.respond_to? :call
      @build_fetcher.expect :latest_build, nil, &status_or_callable
    else
      @build_fetcher.expect :latest_build, get_build(status_or_callable)
    end
    yield
    @subject.check_latest
    assert_mock @build_fetcher
  end

  def expect_led(led)
    @led_monitor.expect :all_off, nil
    @led_monitor.expect :turn_on, nil, [led] unless led.nil?
  end

  def expect_buzz
    @led_monitor.expect :buzz, nil
  end

  def expect_rapid_buzz(args = nil)
    if args.nil?
      @led_monitor.expect :rapid_buzz, nil
    else
      @led_monitor.expect :rapid_buzz, nil, [args]
    end
  end
end
