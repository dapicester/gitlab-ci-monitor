require 'byebug'
require 'minitest/autorun'
require 'webmock/minitest'

ENV['GITLAB_API_PRIVATE_TOKEN'] = 'token'
ENV['GITLAB_PROJECT_ID'] = '12345678'

require_relative '../monitor'
