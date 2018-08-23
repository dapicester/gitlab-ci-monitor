require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'codecov'
SimpleCov.formatter = SimpleCov::Formatter::Codecov

require 'byebug'
require 'minitest/autorun'
require 'webmock/minitest'

ENV['GITLAB_API_PRIVATE_TOKEN'] = 'token'
ENV['GITLAB_PROJECT_ID'] = '12345678'
