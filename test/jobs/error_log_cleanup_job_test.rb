require "test_helper"

class ErrorLogCleanupJobTest < ActiveJob::TestCase
  test "deletes error logs older than 30 days" do
    # Create old and recent error logs
    old_log = ErrorLog.create!(message: "old error", slug: "old-#{SecureRandom.hex(4)}", created_at: 31.days.ago)
    recent_log = ErrorLog.create!(message: "recent error", slug: "recent-#{SecureRandom.hex(4)}", created_at: 1.day.ago)

    assert_difference "ErrorLog.count", -1 do
      ErrorLogCleanupJob.perform_now
    end

    assert_nil ErrorLog.find_by(id: old_log.id)
    assert ErrorLog.find_by(id: recent_log.id)
  end

  test "accepts custom days_old parameter" do
    log_8_days = ErrorLog.create!(message: "8 day error", slug: "eight-#{SecureRandom.hex(4)}", created_at: 8.days.ago)

    assert_difference "ErrorLog.count", -1 do
      ErrorLogCleanupJob.perform_now(days_old: 7)
    end

    assert_nil ErrorLog.find_by(id: log_8_days.id)
  end

  test "does nothing when no old logs exist" do
    assert_no_difference "ErrorLog.count" do
      ErrorLogCleanupJob.perform_now
    end
  end
end
