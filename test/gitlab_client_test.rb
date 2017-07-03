require 'test_helper'

class BuildFetcherTest < Minitest::Test
  def setup
    @url = "#{BuildFetcher::BASE_URI}/projects/#{ENV['GITLAB_PROJECT_ID']}/pipelines"
    @subject = BuildFetcher.new
  end

  def test_latest_build
    pipelines = [
      {
        'id': 47,
        'status': 'pending',
        'ref': 'master',
        'sha': 'a91957a858320c0e17f3a0eca7cfacbff50ea29a'
      },
      {
        'id': 48,
        'status': 'pending',
        'ref': 'develop',
        'sha': 'eb94b618fb5865b26e80fdd8ae531b7a63ad851a'
      }
    ]

    stub_request(:get, @url).to_return(status: 200, body: pipelines.to_json)

    build = @subject.latest_build
    assert_equal pipelines.last, build
  end

  def test_latest_build_error
    stub_request(:get, @url).to_return(status: [401, 'Unauthorized'], body: 'Test stub!')

    assert_raises(BuildFetcher::ServerError) do
      @subject.latest_build
    end
  end

  def test_latest_build_failure
    [SocketError, Timeout::Error].each do |exception|
      stub_request(:any, @url).to_raise(exception)

      assert_raises(BuildFetcher::NetworkError) do
        @subject.latest_build
      end
    end
  end
end
