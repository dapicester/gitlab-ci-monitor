require 'test_helper'

class LedMonitorTest < Minitest::Test
  def setup
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
    LedMonitor::LEDS.each(&blk)
  end

  def expect_digital_write(pin, value)
    @arduino.expect :digital_write, nil, [pin, value]
  end

  def expect_buzz
    expect_digital_write LedMonitor::BUZZER, true
    expect_digital_write LedMonitor::BUZZER, false
  end

  def stub_sleep
    @subject.stub :sleep, nil do
      yield
    end
  end
end
