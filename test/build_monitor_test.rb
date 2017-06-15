require 'test_helper'

class BuildMonitorTest < Minitest::Test
  def setup
    @logger = DummyLogger.new
    @led_monitor = Minitest::Mock.new
    @build_fetcher = Minitest::Mock.new

    @subject = BuildMonitor.new 120,
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
    with_latest :pending do
      expect_led :yellow
    end
  end

  def test_check_latest_failed
    with_latest :failed do
      expect_led :red
      @led_monitor.expect :buzz, nil
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
      @led_monitor.expect :rapid_buzz, nil
    end
  end

  def test_check_latest_fetch_error
    [BuildFetcher::ServerError, BuildFetcher::NetworkError].each do |exception|
      with_latest -> { raise exception } do
        @led_monitor.expect :all_off, nil
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

  def with_latest(status)
    build = status.is_a?(Symbol) ? get_build(status) : status
    @build_fetcher.expect :latest_build, build do
      @led_monitor.expect :all_off, nil
      yield
      @subject.check_latest
    end
  end

  def expect_led(led)
    @led_monitor.expect :turn_on, nil, [led]
  end
end
