require 'test_helper'
require_relative '../lib/led_monitor'

class LedMonitorTest < Minitest::Test
  def setup
    @leds = { red: 9, green: 10, yellow: 11 }
    @buzzer = 5
    @arduino = Minitest::Mock.new
    with_all_leds { |_, pin| expect_digital_write pin, true }
    @subject = LedMonitor.new { @arduino }
  end

  def test_close
    @arduino.expect :close, nil
    @subject.close
  end

  def test_close!
    # TODO: assert on sleep
    stub_sleep do
      @arduino.expect :close, nil
      with_all_leds { |_, pin| expect_digital_write pin, false }
      @subject.close
    end
  end

  def test_all_off
    with_all_leds { |_, pin| expect_digital_write pin, false }
    @subject.all_off
  end

  def test_turn_on
    # valid name
    with_all_leds do |name, pin|
      expect_digital_write pin, true
      @subject.turn_on name
    end

    # TODO: invalid name
  end

  def test_buzz
    # TODO: assert on sleep
    stub_sleep do
      expect_buzz
      @subject.buzz
    end
  end

  def test_rapid_buzz
    # TODO: assert on sleep
    stub_sleep do
      2.times { expect_buzz }
      @subject.rapid_buzz

      n = 4
      n.times { expect_buzz }
      @subject.rapid_buzz count: n
    end
  end

  private

  def with_all_leds(&blk)
    @leds.each(&blk)
  end

  def expect_digital_write(pin, value)
    @arduino.expect :digital_write, nil, [pin, value]
  end

  def expect_buzz
    expect_digital_write @buzzer, true
    expect_digital_write @buzzer, false
  end

  def stub_sleep
    @subject.stub :sleep, nil do
      yield
    end
  end
end

class MultiLedMonitorTest < Minitest::Test
  def setup
    @arduino = Minitest::Mock.new
    @subject = MultiLedMonitor.new { @arduino }
  end

  def test_close
    @arduino.expect :close, nil
    @subject.close
  end

  def test_close!
    @arduino.expect :close, nil
    @subject.close!
  end

  def test_all_off
    leds = { red: 1, green: 2, yellow: 3 }
    leds.values.each { |pin| expect_digital_write pin, false }
    @subject.all_off leds
  end

  def test_turn_on
    pin = 3
    expect_digital_write pin, true
    @subject.turn_on pin
  end

  def test_buzz
    pin = 4
    # TODO: assert on sleep
    stub_sleep do
      expect_buzz pin
      @subject.buzz pin
    end
  end

  def test_rapid_buzz
    pin = 4
    # TODO: assert on sleep
    stub_sleep do
      2.times { expect_buzz pin }
      @subject.rapid_buzz pin

      n = 4
      n.times { expect_buzz pin }
      @subject.rapid_buzz pin, count: n
    end
  end

  private

  def expect_digital_write(pin, value)
    @arduino.expect :digital_write, nil, [pin, value]
  end

  def expect_buzz(pin)
    expect_digital_write pin, true
    expect_digital_write pin, false
  end

  def stub_sleep
    @subject.stub :sleep, nil do
      yield
    end
  end
end
