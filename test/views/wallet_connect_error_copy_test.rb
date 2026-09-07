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

  # --- the coupling this fix rests on ----------------------------------------

  test "the new message survives parseSolanaError untouched" do
    # The fix works ONLY because parseSolanaError passes unrecognised messages
    # through. If a future branch ever matches this wording, the picker would
    # silently show something else again — which is exactly the failure being
    # fixed, so pin it rather than assume it.
    message = "Finish setting up your wallet in Phantom — create or import one, then try again."
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
