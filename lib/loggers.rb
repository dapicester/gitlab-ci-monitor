# frozen_string_literal: true

require 'logger'

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
