# frozen_string_literal: true

require 'colorize'
require 'cgi'
require 'json'
require 'net/http'
require 'uri'

require_relative 'loggers'

# Fetches build info from Gitlab API.
class BuildFetcher
  BASE_URI = 'https://gitlab.com/api/v4'

  class ServerError < StandardError; end
  class NetworkError < StandardError; end

  def initialize(project_id, api_token, logger: DummyLogger.new)
    @project_id = CGI.escape project_id
    @api_token = api_token
    @logger = logger
  end

  def latest_build(branch = 'develop')
    @logger.info { 'Fetching pipelines ...' }

    pipelines_url = "#{BASE_URI}/projects/#{@project_id}/pipelines"
    response = fetch pipelines_url
    pipelines = JSON.parse response.body, symbolize_names: true

    # returned build are already sorted
    latest = pipelines.find { |el| el[:ref] == branch }

    detail_url = "#{pipelines_url}/#{latest[:id]}"
    response = fetch detail_url
    last_build = JSON.parse response.body, symbolize_names: true
    @logger.debug { "Last build on #{branch}: #{last_build.inspect.light_yellow}" }

    last_build
  rescue SocketError, Timeout::Error => ex
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
      @logger.debug { response }

      if response.code.to_i != 200
        @logger.debug { response.body.inspect.light_yellow }
        message = "#{response.message.red} (#{response.code.red}): #{response.body.underline}"
        raise ServerError, message
      end

      response
    end
end
