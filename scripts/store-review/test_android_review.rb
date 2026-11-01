require 'minitest/autorun'
require 'ostruct'

def default_platform(*) ; end
def platform(*) ; yield ; end
def desc(*) ; end
def lane(name, &block)
  (@review_lanes ||= {})[name] = block
end
module UI
  def self.user_error!(message); raise message; end
end
load File.expand_path('../../apps/mobile/fastlane/Fastfile', __dir__)

# Exercise the real lane while substituting the external API boundary.
def google_play_expected_release_notes(**); {}; end
def enable_safe_google_play_review_commit!; @safe_commit_enabled = true; end
def google_play_release_state(**)
  { production: nil, internal: OpenStruct.new(version_codes: ['283']) }
end
def upload_to_play_store(**options)
  (@review_uploads ||= []) << options
end

class AndroidReviewTest < Minitest::Test
  def setup
    @previous_env = ENV.to_h
    ENV['ANDROID_VERSION_CODE'] = '283'
    ENV['ANDROID_RELEASE_STATUS'] = 'completed'
    ENV['GCLOUD_SERVICE_ACCOUNT_CREDENTIALS'] = 'test-only'
    ENV.delete('ANDROID_UPLOAD_METADATA')
    @runner = TOPLEVEL_BINDING.eval('self')
    @runner.instance_variable_set(:@review_uploads, [])
    @runner.instance_variable_set(:@safe_commit_enabled, false)
  end

  def teardown
    ENV.replace(@previous_env)
  end

  def run_review
    @runner.instance_variable_get(:@review_lanes).fetch(:submit_review).call({})
    uploads = @runner.instance_variable_get(:@review_uploads)
    assert_equal 1, uploads.length, 'all changes must use one edit'
    assert @runner.instance_variable_get(:@safe_commit_enabled)
    options = uploads.first
    assert_equal 283, options[:version_code]
    assert_equal 'production', options[:track_promote_to]
    refute options[:skip_upload_changelogs]
    refute options[:changes_not_sent_for_review]
    refute options[:rescue_changes_not_sent_for_review]
    assert options[:skip_upload_aab]
    assert options[:skip_upload_images]
    options
  end

  def test_default_preserves_metadata_and_screenshots
    options = run_review
    assert options[:skip_upload_metadata]
    assert options[:skip_upload_screenshots]
  end

  def test_opt_in_submits_metadata_screenshots_and_build_together
    ENV['ANDROID_UPLOAD_METADATA'] = 'true'
    options = run_review
    refute options[:skip_upload_metadata]
    refute options[:skip_upload_screenshots]
  end
end
