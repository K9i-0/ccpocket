require 'minitest/autorun'
def default_platform(*) ; end
def platform(*) ; yield ; end
def desc(*) ; end
def lane(*) ; end
module UI
  def self.user_error!(message); raise message; end
end
load File.join(__dir__, 'fastlane/Fastfile')

class CommitTest < Minitest::Test
  class API
    attr_reader :calls
    def commit_edit(package, edit, changes_in_review_behavior:, changes_not_sent_for_review:)
      @calls = [package, edit, changes_in_review_behavior, changes_not_sent_for_review]
    end
  end
  class Client
    prepend SafeGooglePlayReviewCommit
    attr_accessor :client, :current_package_name, :current_edit
    def initialize(api)
      @client = api
      @current_package_name = 'com.example.test'
      @current_edit = Struct.new(:id).new('edit-id')
    end
    def ensure_active_edit!; end
    def call_google_api; yield; end
  end
  def test_commit_fails_on_other_review_and_sends_for_review
    api = API.new
    client = Client.new(api)
    client.commit_current_edit!
    assert_equal ['com.example.test', 'edit-id', 'ERROR_IF_IN_REVIEW', false], api.calls
    assert_nil client.current_edit
  end
  def test_old_api_cannot_silently_cancel_existing_review
    api = Object.new
    def api.commit_edit(*); raise 'must never call'; end
    client = Client.new(api)
    error = assert_raises(RuntimeError) { client.commit_current_edit! }
    assert_match(/does not support/, error.message)
    refute_nil client.current_edit
  end
  def test_failed_commit_preserves_edit_for_failure_handling
    api = API.new
    def api.commit_edit(package, edit, changes_in_review_behavior:, changes_not_sent_for_review:)
      raise 'another review exists'
    end
    client = Client.new(api)
    assert_raises(RuntimeError) { client.commit_current_edit! }
    refute_nil client.current_edit
  end
end
