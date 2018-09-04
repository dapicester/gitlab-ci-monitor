require 'test_helper'
require_relative '../lib/build_fetcher'

class BuildFetcherTest < Minitest::Test
  def setup
    project_id = 'company/project'
    @url = "#{BuildFetcher::BASE_URI}/projects/#{CGI.escape project_id}/pipelines"
    @subject = BuildFetcher.new project_id, 'api_token', 'develop'
  end

  def test_latest_build
    pipelines = [
      {
        id: 47,
        status: 'pending',
        ref: 'develop',
        sha: 'a91957a858320c0e17f3a0eca7cfacbff50ea29a'
      },
      {
        id: 48,
        status: 'pending',
        ref: 'develop',
        sha: 'eb94b618fb5865b26e80fdd8ae531b7a63ad851a'
      }
    ]
    stub_request(:get, @url)
      .with(query: { 'ref' => 'develop' })
      .to_return(status: 200, body: pipelines.to_json)

    detail = {
      id: 47,
      status: 'pending',
      ref: 'develop',
      sha: 'a91957a858320c0e17f3a0eca7cfacbff50ea29a',
      before_sha: 'a91957a858320c0e17f3a0eca7cfacbff50ea29a',
      tag: false,
      yaml_errors: nil,
      user: {
        name: 'Administrator',
        username: 'root',
        id: 1,
        state: 'active',
        avatar_url: 'http://www.gravatar.com/avatar/e64c7d89f26bd1972efa854d13d7dd61?s=80&d=identicon',
        web_url: 'http://localhost:3000/root'
      },
      created_at: '2016-08-11T11:28:34.085Z',
      updated_at: '2016-08-11T11:32:35.169Z',
      started_at: nil,
      finished_at: '2016-08-11T11:32:35.145Z',
      committed_at: nil,
      duration: nil,
      coverage: '30.0',
      web_url: 'https://example.com/foo/bar/pipelines/46'
    }
    detail_url = "#{@url}/#{detail[:id]}"
    stub_request(:get, detail_url).to_return(status: 200, body: detail.to_json)

    build = @subject.latest_build
    assert_equal detail, build
  end

  def test_latest_build_error
    stub_request(:get, @url)
      .with(query: { 'ref' => 'develop' })
      .to_return(status: [401, 'Unauthorized'], body: 'Test stub!')

    assert_raises(BuildFetcher::ServerError) do
      @subject.latest_build
    end
  end

  def test_latest_build_failure
    @subject.stub :sleep, nil do
      BuildFetcher::RETRY_EXCEPTIONS.each do |exception|
        stub_request(:any, @url)
          .with(query: { 'ref' => 'develop' })
          .to_raise(exception)

        assert_raises(BuildFetcher::NetworkError) do
          @subject.latest_build
        end
      end
    end
  end
end
