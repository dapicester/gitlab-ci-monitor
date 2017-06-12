require 'test_helper.rb'

class DummyLoggerTest < Minitest::Test
  def setup
    @subject = DummyLogger.new
  end

  def test_methods
    ::LOGGER_METHODS.each do |m|
      assert @subject.respond_to? m
    end
  end
end

class MultiLoggerTest < Minitest::Test
  def setup
    @first = Minitest::Mock.new
    @last = Minitest::Mock.new

    @subject = MultiLogger.new @first, @last
  end

  def test_delegation
    ::LOGGER_METHODS.each do |m|
      string = "#{m} log string"
      @first.expect m, nil, [string]
      @last.expect m, nil, [string]

      @subject.public_send m, string

      block = proc { "#{m} log block" }
      @first.expect(m, nil) { block.call }
      @last.expect(m, nil) { block.call }

      @subject.public_send m, &block
    end
  end
end
