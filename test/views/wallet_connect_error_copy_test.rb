require "test_helper"

# [component] What a connect failure SAYS.
#
# Production, 2026-09-06: the Phantom extension was installed but held no wallet
# — Phantom was sitting on its own "create a new wallet or import an existing
# one" screen. With no keypair, signIn() rejects with Phantom's generic
# "Unexpected error", the connect+signMessage fallback rejects the same way, and
# that string used to reach parseSolanaError — whose generic branch reads it as a
# TRANSACTION failure and answers "Wallet couldn't process the transaction. Check
# wallet connection and USDC balance."
#
# Balance advice, in a connect modal, to someone who attempted no transaction and
# may hold no wallet at all.
class WalletConnectErrorCopyTest < ActionDispatch::IntegrationTest
  LAYOUT = Rails.root.join("app/views/layouts/application.html.erb")
  MAPPER = Rails.root.join("app/javascript/solana_errors.js")

  test "a wallet that cannot answer gets setup copy, not balance advice" do
    src = LAYOUT.read

    assert_includes src, "Finish setting up your wallet in",
                    "a connect failure must be described as a connect failure"
    assert_includes src, "create or import one, then try again",
                    "and must name the action that actually unblocks the user"
  end

  test "a human who declines still reads as a rejection" do
    # A DECLINE IS NOT AN INCAPABILITY. Telling someone who just said no to
    # 'finish setting up your wallet' is its own wrong answer, so the rethrow
    # must let rejections past untouched.
    src = LAYOUT.read
    fallback = src[/if \(!useSignIn\) \{.*?\n          \}/m]

    assert fallback, "the connect fallback block must still exist"
    assert_includes fallback, "user rejected"
    assert_includes fallback, "user declined"
    assert_includes fallback, "e.code === 4001"
    assert_match(/throw e;/, fallback, "a decline is rethrown unchanged")
  end

  test "a server or network failure is NOT diagnosed as a missing wallet" do
    src = LAYOUT.read
    fallback = src[/if \(!useSignIn\) \{.*?\n          \}/m]

    # THE BLOCKER THIS CLOSES. noncePromise fetches OUR OWN server. Inside the
    # try, an offline moment told a user with a perfectly good wallet to "create
    # or import one" — the same confidently-wrong diagnosis this change exists to
    # remove, pointed at a different innocent party.
    assert fallback, "the fallback block must exist"
    nonce_at = src.index("var data = await noncePromise;")
    try_at   = src.index("if (!useSignIn) {")
    open_try = src.index("try {", try_at)

    assert nonce_at < open_try,
           "the nonce fetch must be awaited BEFORE the try, not inside it"
    refute_includes fallback[/try \{.*?\} catch/m].to_s, "noncePromise",
                    "no fetch of our own server may sit under the wallet catch"
  end

  test "the wallet is named the way its brand writes it, not by slug" do
    src = LAYOUT.read

    # provider.name is the lowercase slug, so the sentence read "your wallet in
    # phantom". This diff is the first place provider identity is rendered as
    # user-facing PROSE rather than shipped as a normalised server field.
    assert_includes src, "provider.label || provider.displayName",
                    "prefer the brand's own spelling"
    assert_includes src, "toUpperCase()",
                    "and capitalise the slug rather than printing it raw"
    refute_match(/in ' \+ \(\(provider && provider\.name\)/, src,
                 "the raw slug must not reach the sentence")
  end

  # --- killing the mutants a presence check cannot ---------------------------
  #
  # Review mutated this fix 12 ways and EIGHT survived: negating the decline
  # guard, || -> &&, throw -> console.warn, hoisting the throw above the guard,
  # commenting the throw out, dropping the /i, and poisoning the copy. Every one
  # survived because the tests asserted that text was PRESENT, and presence is
  # blind to form and order. These assert both.

  MESSAGE = "Finish setting up your wallet in "

  test "the decline guard keeps its exact form" do
    src = LAYOUT.read

    # Pinned verbatim: || -> && silently narrows the guard to declines that
    # satisfy BOTH patterns, i.e. none, and a presence check cannot see it.
    assert_includes src,
                    "if (/user rejected/i.test(em) || /user declined/i.test(em) || (e && e.code === 4001)) throw e;",
                    "negation, || -> &&, or a dropped /i must all fail here"
  end

  test "the guard runs BEFORE the rethrow, not after it" do
    src = LAYOUT.read
    guard_at = src.index("if (/user rejected/i.test(em)")
    throw_at = src.index(MESSAGE)

    # Hoisting the throw above the guard makes every decline read as a missing
    # wallet. Both lines still exist, so only their ORDER catches it.
    assert guard_at, "the guard must exist"
    assert throw_at, "the rethrow must exist"
    assert guard_at < throw_at,
           "a decline must be rethrown before the setup message can be composed"
  end

  test "the setup case throws rather than merely logging" do
    src = LAYOUT.read
    line = src[/^.*#{Regexp.escape(MESSAGE)}.*$/]

    # throw -> console.warn leaves the string on the page and the user with
    # nothing: the picker renders whatever it caught, and it caught nothing.
    assert_includes line, "throw new Error(",
                    "the message must be raised, not logged"
  end

  # --- the coupling this fix rests on ----------------------------------------

  test "the new message survives parseSolanaError untouched" do
    # The fix works ONLY because parseSolanaError passes unrecognised messages
    # through. If a future branch ever matches this wording, the picker would
    # silently show something else again — which is exactly the failure being
    # fixed, so pin it rather than assume it.
    # READ THE MESSAGE THE CODE ACTUALLY THROWS. A hardcoded copy of it cannot
    # fail when the copy changes, and that is the whole risk being guarded here:
    # edit the sentence to contain "insufficient funds" and the mapper rewrites
    # it straight back into the balance advice this task exists to remove.
    line = LAYOUT.read[/^\s*throw new Error\('Finish setting up.*$/]
    assert line, "the setup message must be THROWN, as a one-line literal"
    message = line[/'(.*)'\);/, 1]
              .gsub("' + brand + '", "Phantom")
              .gsub('\\u2014', "\u2014")
    mapper  = MAPPER.read

    assert_includes mapper, "return msg;",
                    "the pass-through branch is what carries this message"

    # Every regex literal the mapper tests a message against.
    mapper.scan(%r{/((?:[^/\\\n]|\\.)+)/([im]*)\.test\(msg\)}).each do |body, flags|
      re = Regexp.new(body, flags.include?("i") ? Regexp::IGNORECASE : 0)
      refute_match re, message,
                   "parseSolanaError would rewrite the setup message via /#{body}/#{flags}"
    end
    refute_equal "Unexpected error", message
  end

  test "the shared transaction wording is left alone for the paths that own it" do
    # The entry flows raise real transaction errors and their copy is correct.
    # This fix must not have widened its blast radius by editing the mapper.
    assert_includes MAPPER.read,
                    "Wallet couldn't process the transaction. Check wallet connection and USDC balance.",
                    "the generic transaction branch stays for the entry paths"
  end
end
