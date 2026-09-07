require "test_helper"

# The sweeper that re-drives stranded outbox rows.
#
# THE FAILURE IT EXISTS FOR, measured on mainnet 2026-09-07: settling
# turf-totals-alpha-contest-v1 paid dunkpark4@gmail.com $100 and left their
# winner email at sent=false, sent_at=nil and error=nil, while the other
# winner's row — created in the same second — sent fine. Sidekiq held nothing:
# enqueued 0, retry 0, dead 0. No retry was coming, and a player who had been
# paid would never have been told.
#
# So the case under test is specifically the SILENT one. A row with an error is
# already Sidekiq's problem; a row with no error and no job is nobody's, and
# that is the hole.
class EmailDeliveryResendJobTest < ActiveJob::TestCase
  def row(created_at:, sent: false, error: nil, to: "x@example.com")
    EmailDelivery.create!(
      mailer: "ContestMailer", action: "winnings", email_key: "ContestMailer#winnings",
      to: to, sent: sent, error: error,
      args: ActiveJob::Arguments.serialize([]), kwargs: ActiveJob::Arguments.serialize([{}]).first,
      created_at: created_at
    )
  end

  setup { EmailDelivery.delete_all }

  test "re-enqueues a row stranded past the threshold" do
    stranded = row(created_at: 45.minutes.ago)

    assert_enqueued_with(job: EmailDeliveryJob, args: [stranded.id]) do
      assert_equal 1, EmailDeliveryResendJob.perform_now
    end
  end

  # THE POINT OF THE THRESHOLD. A row is created and its job enqueued in the
  # same breath, so a young unsent row is in flight, not stranded. Sweeping it
  # would put a second copy of a real email in someone's inbox.
  test "leaves a young row alone so an in-flight delivery is not double-sent" do
    row(created_at: 2.minutes.ago)

    assert_no_enqueued_jobs only: EmailDeliveryJob do
      assert_equal 0, EmailDeliveryResendJob.perform_now
    end
  end

  test "ignores rows that already sent" do
    row(created_at: 45.minutes.ago, sent: true)

    assert_no_enqueued_jobs only: EmailDeliveryJob do
      assert_equal 0, EmailDeliveryResendJob.perform_now
    end
  end

  # A row that FAILED loudly is already inside Sidekiq's retry machinery, but it
  # is still unsent, and leaving it out would mean a permanent outage never
  # recovers once its retries are exhausted. Swept like any other.
  test "sweeps a stranded row that recorded an error" do
    stranded = row(created_at: 45.minutes.ago, error: "Net::SMTPServerBusy")

    assert_enqueued_with(job: EmailDeliveryJob, args: [stranded.id]) do
      EmailDeliveryResendJob.perform_now
    end
  end

  test "the threshold is overridable for an operator running it by hand" do
    recent = row(created_at: 5.minutes.ago)

    assert_enqueued_with(job: EmailDeliveryJob, args: [recent.id]) do
      assert_equal 1, EmailDeliveryResendJob.perform_now(stranded_after_minutes: 1)
    end
  end

  test "sweeps every stranded row, not just the first" do
    3.times { |i| row(created_at: 45.minutes.ago, to: "w#{i}@example.com") }

    assert_enqueued_jobs 3, only: EmailDeliveryJob do
      assert_equal 3, EmailDeliveryResendJob.perform_now
    end
  end

  # END TO END on the exact shape that was missed, built through the REAL
  # producer rather than a hand-made row: EmailDelivery.deliver is what records
  # the intent, so its serialized args are the ones deliver_now! has to be able
  # to rebuild a mailer from. A synthetic row with empty args passes a sweeper
  # test while proving nothing — it fails inside the mailer, not the sweep.
  test "a stranded winner email reaches sent after a tick" do
    entry = contests(:one).entries.create!(
      user: users(:alex), status: "complete", rank: 1, payout_cents: 4500, score: 1.0
    )
    stranded = nil
    perform_enqueued_jobs(only: EmailDeliveryJob) do
      stranded = EmailDelivery.deliver(ContestMailer, :winnings, entry, to: users(:alex).email)
    end
    # Strand it exactly as production did: unsent, no error, nothing queued.
    stranded.update!(sent: false, sent_at: nil, error: nil, created_at: 45.minutes.ago)

    perform_enqueued_jobs(only: EmailDeliveryJob) { EmailDeliveryResendJob.perform_now }

    assert stranded.reload.sent?, "the sweep should have driven the row to sent"
    assert_not_nil stranded.sent_at
    assert_nil stranded.error
  end
end
