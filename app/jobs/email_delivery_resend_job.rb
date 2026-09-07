# Re-drives EmailDelivery rows that were never sent and have nothing left to
# send them.
#
# WHY THIS EXISTS. EmailDelivery.deliver records the intent durably and then
# enqueues EmailDeliveryJob; deliver_now! marks the row sent, or records the
# error and re-raises so Sidekiq retries. That covers a failing send. It does
# NOT cover a send that never reports anything — and on 2026-09-07 that is
# exactly what happened on mainnet: settling turf-totals-alpha-contest-v1 paid
# dunkpark4@gmail.com $100 and left their winner email at sent=false,
# sent_at=nil, error=nil, while a row created in the SAME SECOND for the other
# winner sent fine. Sidekiq held nothing — enqueued 0, retry 0, dead 0 — so no
# retry was ever going to come. A real player had been paid and would simply
# never have been told. It was found by hand, and only because someone looked.
#
# EmailDelivery.resend_unsent! already existed for this and its own comment says
# so. Nothing called it. This is the caller.
#
# THE THRESHOLD IS THE WHOLE DESIGN. The row is created and its job enqueued in
# the same breath, so an unsent row seconds old is almost always in flight, not
# stranded — sweeping those would double-send real mail. STRANDED_AFTER is the
# line between "still going" and "nobody is coming", and it is deliberately
# longer than Sidekiq's own retry backoff so a row being retried normally is
# left to finish on its own.
#
# Re-enqueues rather than delivering inline: EmailDeliveryJob owns the send, and
# routing through it keeps one path to the provider instead of a second one that
# could drift.
class EmailDeliveryResendJob < ApplicationJob
  queue_as :default

  STRANDED_AFTER = 30.minutes

  def perform(stranded_after_minutes: nil)
    cutoff = (stranded_after_minutes&.to_f&.minutes || STRANDED_AFTER).ago
    scope  = EmailDelivery.unsent.where(created_at: ..cutoff)
    ids    = scope.pluck(:id)

    ids.each { |id| EmailDeliveryJob.perform_later(id) }

    Rails.logger.info(
      "[email_delivery_resend] requeued=#{ids.size} cutoff=#{cutoff.iso8601}" \
      "#{" ids=#{ids.join(',')}" unless ids.empty?}"
    )
    ids.size
  end
end
