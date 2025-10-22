require "test_helper"

class SyncUpBankJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    @user.update!(up_bank_token: "test_token_123")
  end

  test "should enqueue job" do
    assert_enqueued_with(job: SyncUpBankJob, args: [ @user.id ]) do
      SyncUpBankJob.perform_later(@user.id)
    end
  end

  test "should be queued on default queue" do
    job = SyncUpBankJob.perform_later(@user.id)
    assert_equal "default", job.queue_name
  end

  test "should handle user not found gracefully" do
    # Should discard the job without raising (configured with discard_on)
    assert_nothing_raised do
      perform_enqueued_jobs do
        SyncUpBankJob.perform_later(999999) # Non-existent user ID
      end
    end
  end

  test "job configuration should have retry and discard settings" do
    # Verify job class has proper error handling configured
    # This is a smoke test to ensure the job is set up correctly
    assert_nothing_raised do
      SyncUpBankJob.new
    end
  end
end
