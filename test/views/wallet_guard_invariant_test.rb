require "test_helper"

# [component] NO SIGNING VIEW MAY DEREFERENCE detect() DIRECTLY.
#
# The bug this change fixed was not one bad line — it was the same bad line in
# six places, each written independently, each correct-looking. Fixing six call
# sites without pinning the shape leaves the seventh free to be written the same
# way tomorrow, and it will fail identically: `null is not an object
# (evaluating 'provider.connect')` in a modal, on a phone, with no test red.
#
# So this asserts the INVARIANT rather than the six edits. A view that reaches
# for a wallet must go through requireProvider(), which answers a missing wallet
# with advice the device can act on.
#
# WHAT THIS TEST CANNOT DO, stated so nobody mistakes it for more: it reads
# source, so it proves a CALL SHAPE, not behaviour. The behaviour is owned by
# test/lib/wallet_require_provider_js_test.rb (the copy rules),
# test/integration/wallet_stub_parity_test.rb (stub and module agree) and
# e2e/wallet_require_provider.spec.js (the module actually arrives). This one
# exists to stop the SEVENTH call site, which none of those would notice.
class WalletGuardInvariantTest < ActiveSupport::TestCase
  VIEWS = Rails.root.join("app/views")

  # The sign-in picker is the one deliberate exception, and it is exempt for a
  # reason rather than by oversight: solanaConnectAndVerify picks a provider BY
  # NAME from the picker the user just chose from, and already renders its own
  # failure through that modal. It is also the one flow that currently works on
  # mobile (via the Phantom deeplink), so routing it through this guard would
  # risk the only thing phones can do today.
  EXEMPT = ["app/views/layouts/application.html.erb"].freeze

  def offending_lines
    Dir.glob(VIEWS.join("**/*.erb")).flat_map do |path|
      rel = Pathname.new(path).relative_path_from(Rails.root).to_s
      next [] if EXEMPT.include?(rel)

      File.readlines(path).each_with_index.filter_map do |line, i|
        # `walletProvider.detect()` assigned into a variable is the shape that
        # precedes a dereference. Reading it inside a boolean guard
        # (`if (!walletProvider.detect())`) is not the bug and is not flagged.
        next unless line =~ /=\s*(?:window\.)?walletProvider\s*&&\s*(?:window\.)?walletProvider\.detect\(\)|=\s*(?:window\.)?walletProvider\.detect\(\)/
        "#{rel}:#{i + 1}"
      end
    end
  end

  test "no view assigns walletProvider.detect() into a variable it will dereference" do
    offenders = offending_lines

    assert_empty offenders,
                 "These views take a provider from detect(), which returns null on every " \
                 "mobile browser, and dereference it — the exact shape that printed " \
                 "\"null is not an object (evaluating 'provider.connect')\" into a " \
                 "transaction modal on 2026-09-07. Use walletProvider.requireProvider() " \
                 "instead; it throws a message the device can act on, and every one of " \
                 "these call sites already sits in a try/catch that renders err.message.\n  " +
                 offenders.join("\n  ")
  end

  test "the guard is actually in use, so the scan above is not vacuous" do
    # A REGEX THAT MATCHES NOTHING PASSES THE TEST ABOVE FOREVER. Pin the
    # positive side too: the call sites this change created must still be there,
    # or the invariant is being enforced over an empty set.
    users = Dir.glob(VIEWS.join("**/*.erb")).count { |p| File.read(p).include?("walletProvider.requireProvider()") }

    assert_operator users, :>=, 6,
                    "expected at least the six converted signing views to call " \
                    "requireProvider(); found #{users}. If a call site was removed on " \
                    "purpose, lower this floor deliberately rather than deleting the check."
  end
end
