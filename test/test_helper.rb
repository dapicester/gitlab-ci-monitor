require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

require 'byebug'
require 'minitest/autorun'
require 'webmock/minitest'

ENV['GITLAB_API_PRIVATE_TOKEN'] = 'token'
ENV['GITLAB_PROJECT_ID'] = '12345678'
