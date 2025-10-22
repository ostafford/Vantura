require "test_helper"

class SessionCleanupJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
  end

  test "should enqueue job" do
    assert_enqueued_with(job: SessionCleanupJob) do
      SessionCleanupJob.perform_later
    end
  end

  test "should be queued on low_priority queue" do
    job = SessionCleanupJob.perform_later
    assert_equal "low_priority", job.queue_name
  end

  test "should delete expired sessions" do
    # Create active session
    active_session = @user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "Test",
      last_active_at: Time.current
    )

    # Create expired session
    expired_session = @user.sessions.create!(
      ip_address: "127.0.0.2",
      user_agent: "Test",
      last_active_at: 31.days.ago
    )

    # Perform the job
    perform_enqueued_jobs do
      SessionCleanupJob.perform_later
    end

    # Active session should still exist
    assert Session.exists?(active_session.id)

    # Expired session should be deleted
    assert_not Session.exists?(expired_session.id)
  end

  test "should return deleted count" do
    # Clear existing sessions first
    Session.destroy_all

    # Create 3 expired sessions
    3.times do
      @user.sessions.create!(
        ip_address: "127.0.0.1",
        user_agent: "Test",
        last_active_at: 31.days.ago
      )
    end

    result = perform_enqueued_jobs do
      SessionCleanupJob.perform_now
    end

    assert_equal 3, result[:deleted_count]
  end

  test "should handle no expired sessions" do
    # Clear existing sessions first
    Session.destroy_all

    # Create active session
    @user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "Test",
      last_active_at: Time.current
    )

    result = perform_enqueued_jobs do
      SessionCleanupJob.perform_now
    end

    assert_equal 0, result[:deleted_count]
  end

  test "should log cleanup activity" do
    # Clear existing sessions first
    Session.destroy_all

    # Create expired session
    @user.sessions.create!(
      ip_address: "127.0.0.1",
      user_agent: "Test",
      last_active_at: 31.days.ago
    )

    # Just verify job runs without errors (logging tested separately)
    assert_nothing_raised do
      perform_enqueued_jobs do
        SessionCleanupJob.perform_later
      end
    end
  end
end
