# frozen_string_literal: true

require 'colorize'
require 'cgi'
require 'json'
require 'net/https'
require 'uri'

require_relative 'loggers'

# Fetches build info from Gitlab API.
class BuildFetcher
  BASE_URI = 'https://gitlab.com/api/v4'
  NUM_RETRIES = 5
  RETRY_INTERVAL = 5 # seconds
  RETRY_EXCEPTIONS = [
    SocketError,
    OpenSSL::OpenSSLError,
    Timeout::Error
  ]

  class ServerError < StandardError; end
  class NetworkError < StandardError; end

  def initialize(project_id, api_token, branch, logger: DummyLogger.new)
    @project_id = project_id
    @api_token = api_token
    @branch = branch
    @logger = logger
  end

  def latest_build
    @logger.info { "#{@project_id.light_blue}: Fetching pipelines ..." }

    retries ||= 0

    pipelines_url = "#{BASE_URI}/projects/#{CGI.escape @project_id}/pipelines"
    response = fetch pipelines_url
    pipelines = JSON.parse response.body, symbolize_names: true

    # returned build are already sorted
    latest = pipelines.find { |el| el[:ref] == @branch }

    detail_url = "#{pipelines_url}/#{latest[:id]}"
    response = fetch detail_url
    last_build = JSON.parse response.body, symbolize_names: true
    @logger.debug { "#{@project_id.light_blue}: Last build on #{@branch}: #{last_build.inspect.light_yellow}" }

    last_build
  rescue *RETRY_EXCEPTIONS => ex
    if (retries += 1) < NUM_RETRIES
      @logger.warn { "#{@project_id.light_blue}: #{ex.class}: #{ex.message}, retrying ..." }
      sleep RETRY_INTERVAL
      retry
    end

    @logger.error { "#{@project_id.light_blue}: failed" }
    raise NetworkError, ex
  end

  private

    def fetch(url)
      uri = URI url
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new uri
        request.add_field 'PRIVATE-TOKEN', @api_token

        http.request request
      end
      @logger.debug { "#{@project_id.light_blue}: #{response }"}

      if response.code.to_i != 200
        @logger.debug { "#{@project_id.light_blue}: #{response.body.inspect.light_yellow}" }
        message = "#{@project_id.light_blue}: #{response.message.red} (#{response.code.red}): #{response.body.underline}"
        raise ServerError, message
      end

      response
    end
end
