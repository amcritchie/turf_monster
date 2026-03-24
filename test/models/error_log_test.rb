require "test_helper"

class ErrorLogTest < ActiveSupport::TestCase
  test "capture! stores exception details" do
    exception = RuntimeError.new("something broke")
    exception.set_backtrace(caller)

    log = ErrorLog.capture!(exception)

    assert_equal "something broke", log.message
    assert_includes log.inspect, "RuntimeError"
    assert log.backtrace.present?
    assert_equal "error-log-#{log.id}", log.slug
  end

  test "capture! creates log without target or parent, which can be set after" do
    user = users(:alex)
    contest = contests(:one)
    exception = RuntimeError.new("bad pick")
    exception.set_backtrace(caller)

    log = ErrorLog.capture!(exception)

    assert_nil log.target_type
    assert_nil log.parent_type

    log.target = user
    log.target_name = user.slug
    log.parent = contest
    log.parent_name = contest.slug
    log.save!

    log.reload
    assert_equal "User", log.target_type
    assert_equal user.id, log.target_id
    assert_equal user.slug, log.target_name
    assert_equal "Contest", log.parent_type
    assert_equal contest.id, log.parent_id
    assert_equal contest.slug, log.parent_name
  end

  test "capture! without target or parent" do
    exception = RuntimeError.new("orphan error")
    exception.set_backtrace(caller)

    log = ErrorLog.capture!(exception)

    assert_nil log.target_type
    assert_nil log.target_id
    assert_nil log.target_name
    assert_nil log.parent_type
    assert_nil log.parent_id
    assert_nil log.parent_name
  end

  test "capture! stores backtrace as JSON array" do
    exception = RuntimeError.new("trace test")
    exception.set_backtrace(["app/models/entry.rb:10:in `confirm!'", "gems/activerecord/lib/base.rb:100:in `save'"])

    log = ErrorLog.capture!(exception)
    frames = JSON.parse(log.backtrace)

    assert_kind_of Array, frames
    assert_includes frames, "app/models/entry.rb:10:in `confirm!'"
    assert_not_includes frames, "gems/activerecord/lib/base.rb:100:in `save'"
  end
end
