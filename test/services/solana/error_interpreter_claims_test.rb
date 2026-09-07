require "test_helper"

# Guards the CLAIMS the error-interpreter's comments make about where the
# no_funding blocker sends a blocked player.
#
# WHY A TEST FOR COMMENTS. Solana::ErrorInterpreter is the seam where an
# on-chain / RPC failure becomes what a user is TOLD about their money. Three
# comments in the service, and two in its test, said the no_funding blocker
# means the board "opens Top Up Wallet". It does not, and had not for some
# time: the board answers no_funding through selectionBoard#showFundsNeeded,
# which routes to Get USDC (modals/_buy_usdc) or — for the USDC kill-switch
# audience — Buy an Entry Token (modals/_buy_entry_token). A comment naming the
# wrong remediation surface teaches the next reader the wrong money path, which
# is why this is pinned rather than left to review.
#
# WHAT THIS GUARD DOES AND DOES NOT CATCH, stated plainly so nobody trusts it
# further than it goes:
#
#   · The POSITIVE assertions are the enforcement. Each no_funding site must
#     name the dispatcher and BOTH real destinations, and the service must
#     carry the two conditions under which Top Up Wallet would regain an
#     entrance. Those cannot pass vacuously: an empty or unread file fails
#     them.
#   · The NEGATIVE assertions are exact needles, each proven below against the
#     historical sentence it was written to catch. They stop the SPECIFIC false
#     claims from returning verbatim. They will not catch an arbitrary new
#     paraphrase — the positive assertions and review are what cover that.
#
# This file is deliberately NOT among the files it scans: it quotes the defect
# on purpose, in PRE_FIX_SENTENCES, so the needles can be proven to bite.
class Solana::ErrorInterpreterClaimsTest < ActiveSupport::TestCase
  SERVICE_PATH = Rails.root.join("app/services/solana/error_interpreter.rb")
  SPEC_PATH    = Rails.root.join("test/services/solana/error_interpreter_test.rb")

  SCANNED = {
    "app/services/solana/error_interpreter.rb"       => SERVICE_PATH,
    "test/services/solana/error_interpreter_test.rb" => SPEC_PATH
  }.freeze

  # Ruby comments wrap, so a claim can straddle two lines ("(Top Up\n # Wallet,
  # Coinbase-forward)"). Rejoin comment continuations and squeeze whitespace so a
  # needle matches the SENTENCE rather than the line the author happened to break
  # it on. Without this, the wrapped site slips every needle silently.
  def flatten(source)
    source.gsub(/\n[ \t]*#[ \t]?/, " ").gsub(/\s+/, " ")
  end

  # The six sentences these files carried before this task, verbatim. Each
  # needle below is proven against them, so a needle that can never match
  # anything fails HERE instead of passing as a soundness claim it cannot keep.
  PRE_FIX_SENTENCES = [
    "# / token-only. Maps to the no_funding blocker → board opens Top Up Wallet.",
    "#   meaning \"the managed wallet can't cover the USDC entry fee → Top Up\":",
    "# Map BOTH to no_funding/web2 so the board opens the Top Up Wallet instead",
    "# managed USDC entry that underfunds maps to no_funding/web2 (Top Up\n      # Wallet, Coinbase-forward), NOT the web3 deposit/currency picker.",
    "test \"0x1772 in a web2 session maps to no_funding/web2 (Top Up Wallet), not the web3 deposit modal\" do",
    "# the board opens the Top Up Wallet instead of attempting a doomed on-chain entry."
  ].freeze

  FALSE_CLAIM_NEEDLES = [
    /\bopens\s+Top\s+Up\s+Wallet\b/i,
    /\bopens\s+the\s+Top\s+Up\s+Wallet\b/i,
    /entry fee → Top Up/i,
    /maps to no_funding\/web2 \(Top Up Wallet/i,
    /no_funding\/web2 \(Top Up Wallet\), not/i
  ].freeze

  # --- anti-vacuity controls -------------------------------------------------
  #
  # A source-scanning test is exit-blind: if the read returns "" (moved file,
  # wrong root, a rename) every refute_match below passes and the suite reports
  # green on a file it never opened. These two tests are the proof that the scan
  # reached real content, and they run before anything is concluded from it.

  test "CONTROL: the scan reads real, substantial content from both files" do
    SCANNED.each do |label, path|
      assert path.exist?, "#{label} must exist for this guard to mean anything"
      body = path.read
      assert_operator body.bytesize, :>, 2_000,
                      "#{label} read back #{body.bytesize} bytes — the scan did not reach the real file"
      assert_includes body, "no_funding",
                      "#{label} must contain the blocker reason this guard is about"
      assert_includes flatten(body), "no_funding",
                      "flatten() must not destroy the content it normalizes in #{label}"
    end
  end

  test "CONTROL: every false-claim needle matches at least one real historical sentence" do
    haystack = flatten(PRE_FIX_SENTENCES.join("\n"))
    FALSE_CLAIM_NEEDLES.each do |needle|
      assert_match needle, haystack,
                   "needle #{needle.inspect} matches none of the sentences it was written to catch — " \
                   "it is dead, and would claim a soundness it cannot deliver"
    end
    # And the control has a control: the needles must not match arbitrary prose,
    # or "matches something" would be worthless.
    FALSE_CLAIM_NEEDLES.each do |needle|
      refute_match needle, "The funds wall routes through showFundsNeeded to Get USDC.",
                   "needle #{needle.inspect} matches a correct sentence — it is too broad"
    end
  end

  # --- the claim guard -------------------------------------------------------

  test "neither file claims the no_funding blocker's destination is Top Up Wallet" do
    SCANNED.each do |label, path|
      flat = flatten(path.read)
      FALSE_CLAIM_NEEDLES.each do |needle|
        refute_match needle, flat,
                     "#{label} says the no_funding blocker leads to Top Up Wallet. It does not: the board " \
                     "answers no_funding through selectionBoard#showFundsNeeded, which routes to Get USDC " \
                     "(modals/_buy_usdc) or, for the USDC kill-switch audience, Buy an Entry Token " \
                     "(modals/_buy_entry_token)."
      end
    end
  end

  test "the service names the dispatcher at every no_funding mapping" do
    flat = flatten(SERVICE_PATH.read)
    # Three branches return a no_funding blocker: the no-entry-tokens raise, the
    # web2 USDC pre-check / raw-0x1 backstop, and the web2 arm of 6002. Each owes
    # the reader the dispatcher that actually answers it.
    assert_operator flat.scan("showFundsNeeded").size, :>=, 3,
                    "each of the three no_funding branches must name showFundsNeeded, the dispatcher " \
                    "that answers that blocker on the board"
  end

  test "the service names both real destinations at EVERY no_funding mapping" do
    flat = flatten(SERVICE_PATH.read)
    # PER-SITE, not file-wide. A whole-file assert_includes is satisfied by ONE
    # mention anywhere, so a single site could drop both destinations and this
    # guard would stay green — exactly what the header above promises it does
    # not do. Same shape as the dispatcher assertion: three no_funding branches,
    # so each needle owes three appearances.
    {
      "Get USDC"                => "the destination for everyone but the kill-switch audience",
      "modals/_buy_usdc"        => "the file behind Get USDC",
      "Buy an Entry Token"      => "the destination for the USDC kill-switch audience",
      "modals/_buy_entry_token" => "the file behind Buy an Entry Token"
    }.each do |needle, why|
      assert_operator flat.scan(needle).size, :>=, 3,
                      "every no_funding branch must name #{needle} — #{why}. A file-wide " \
                      "mention is not enough: each of the three sites owes the reader both " \
                      "destinations, not just whichever site happens to carry them."
    end
  end

  test "the service names the CONDITIONS under which Top Up Wallet regains an entrance" do
    flat = flatten(SERVICE_PATH.read)
    # NAME THE CONDITION, NOT THE STATE. A flat "it does not open Top Up Wallet"
    # rots the day someone adds a caller; naming both closed doors tells the next
    # reader exactly what would reopen one.
    assert_includes flat, "showWalletTopup",
                    "the note must name the orphaned opener — the first of the two closed doors"
    assert_includes flat, "returnModal",
                    "the note must name the hub prop — the second of the two closed doors"
    assert_match(/regains an entrance/i, flat,
                 "the note must say what would CHANGE, not merely assert today's state")
  end

  test "the spec's web2 0x1772 case names the dispatcher rather than a modal it never opens" do
    flat = flatten(SPEC_PATH.read)
    assert_includes flat, "showFundsNeeded",
                    "the web2/0x1772 case and the funding-preflight note must name the dispatcher"
    assert_includes flat, "Get USDC",
                    "the spec must name the destination a blocked player actually lands on"
  end
end
