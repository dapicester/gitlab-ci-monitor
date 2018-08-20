# frozen_string_literal: true

require 'arduino_firmata'

require_relative 'loggers'

# Controls LEDs on an Arduino board with Firmata.
class LedMonitor
  def initialize(red: 9, green: 10, yellow: 11, buzzer: 5, logger: DummyLogger.new)
    @leds = { red: red, green: green, yellow: yellow }
    @buzzer = buzzer
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
    @leds.keys.each { |led| turn_on led }
  end

  def close
    @logger.debug { 'Closing Firmata connection' }
    @arduino.close
  end

  # :nocov:
  def close!
    # workaround for "log writing failed. can't be called from trap context"
    @leds.values.each { |pin| @arduino.digital_write pin, false }
    sleep 0.1
    @arduino.close
  end
  # :nocov:

  def all_off
    @logger.debug { 'Turning off all leds' }
    @leds.values.each { |pin| @arduino.digital_write pin, false }
  end

  def turn_on(led)
    @logger.debug { "Turning on #{led} led" }
    @arduino.digital_write @leds[led], true
  end

  def buzz(duration = 0.5)
    @logger.debug { "Buzzing for #{duration} sec" }
    @arduino.digital_write @buzzer, true
    sleep duration
    @arduino.digital_write @buzzer, false
  end

  def rapid_buzz(count: 2, duration: 0.05)
    @logger.debug { "Buzzing #{count} times" }
    count.times do
      buzz duration
      sleep duration
    end
  end
end
