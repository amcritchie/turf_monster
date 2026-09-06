require "test_helper"

# admin-state-rescue-messages-mislead — the three `(X rescue "...")` fallbacks in
# app/views/contract/_section_admin_state.html.erb must describe the state that
# ACTUALLY produces them.
#
# THE DEFECT WAS THE MESSAGE, NOT THE RESCUE. Each fallback named an env var and
# declared it "not set". None of those three variables can reach a RENDERED page
# unset:
#
#   * SOLANA_PROGRAM_ID and SOLANA_NETWORK back LOAD-TIME constants that raise
#     during eager load in production (OPSEC-012; for NETWORK, unset, empty and
#     whitespace-only alike since empty-solana-network-fails-open / PR 559).
#     production.rb sets `config.eager_load = true`, so a missing value stops
#     BOOT — the dyno never serves the page the fallback would appear on. Dev
#     and test resolve both to devnet defaults and cannot raise at all.
#   * Solana::Config.squads_vault_pda never raises anywhere: env override, else
#     a network-keyed default. And its key is ABSENT from turf-monster-mainnet
#     and turf-monster-qa alike (re-verified 2026-09-06 by KEY PRESENCE —
#     `heroku config --json -a <app> | jq 'has("SOLANA_SQUADS_VAULT_PDA")'`
#     answers false on both), which is the CORRECT state: the cluster default is
#     the path every production render takes. So "(SOLANA_SQUADS_VAULT_PDA not
#     set)" called the normal production state an error.
#
# WHAT SURVIVES is Solana::Config itself failing to resolve — a Zeitwerk load
# failure raises NameError, which a bare `rescue` modifier catches. That is the
# state the messages now name.
#
# WHY THE TESTS REMOVE A CONSTANT. `remove_const` makes `Solana::Config::NETWORK`
# raise NameError on read, which is not an approximation of the surviving
# trigger — it is the same exception class from the same cause (an unresolvable
# constant under Solana::Config). Same technique, and the same fork-isolation
# argument, as ContractUpgradeAuthorityTest's `with_network`.
class ContractAdminStateFallbacksTest < ActionDispatch::IntegrationTest
  PARTIAL = "app/views/contract/_section_admin_state.html.erb".freeze

  # Extract a cell BY POSITION off its <dt>. A card that failed to render (the
  # admin gate, a 500) returns nil here rather than silently satisfying an
  # assertion about what the page does not say.
  def cell_for(body, label)
    body[%r{#{Regexp.escape(label)}</dt>\s*<dd[^>]*>\s*(.*?)\s*</dd>}m, 1]&.strip
  end

  def without_const(name)
    previous = Solana::Config.const_get(name)
    Solana::Config.send(:remove_const, name)
    yield
  ensure
    Solana::Config.const_set(name, previous)
  end

  setup { log_in_as(users(:alex)) }

  # --- 1. PROGRAM_ID: absence stops boot, so it never shows up here ---

  test "the Program ID fallback names the load failure, not a missing var" do
    without_const(:PROGRAM_ID) do
      get contract_path
      assert_response :success

      value = cell_for(response.body, "Program ID")
      assert value.present?,
        "the admin card rendered no Program ID cell - the assertions below would pass vacuously"
      assert_match(/Solana::Config did not load/, value,
        "the Program ID fallback must name the only state that produces it: Solana::Config failing to resolve")
      assert_match(/stops boot/, value,
        "the fallback must tell the reader an unset SOLANA_PROGRAM_ID stops boot rather than rendering here")
      assert_no_match(/SOLANA_PROGRAM_ID not set/, value,
        "an unset SOLANA_PROGRAM_ID raises during eager load, so it cannot be the cause of a rendered fallback")
    end
  end

  # --- 2. squads_vault_pda: absence is the CORRECT production state ---

  test "the Upgrade authority fallback does not call the correct production state an error" do
    raiser = ->(*) { raise NameError, "uninitialized constant Solana::Config" }

    Solana::Config.stub(:squads_vault_pda, raiser) do
      get contract_path
      assert_response :success

      value = cell_for(response.body, "Upgrade authority")
      assert value.present?,
        "the admin card rendered no Upgrade authority cell - the assertions below would pass vacuously"
      assert_match(/Solana::Config did not load/, value,
        "squads_vault_pda cannot raise on its own, so the fallback must name the load failure")
      assert_match(/correctly unset/, value,
        "SOLANA_SQUADS_VAULT_PDA is absent on both deployed apps by design - the message must say so")
      assert_no_match(/SOLANA_SQUADS_VAULT_PDA not set/, value,
        "the key is absent on turf-monster-mainnet and turf-monster-qa alike; calling that 'not set' " \
        "points the reader at the wrong cause")
    end
  end

  # --- 3. NETWORK: the fallback is DEAD, and the message says so ---
  #
  # Established here rather than inherited. The first draft of this suite tried
  # to RENDER the NETWORK fallback and could not: the application layout reads
  # Solana::Config.devnet? on the body tag of every render, unrescued, and
  # devnet? reads NETWORK. So anything that makes NETWORK unreadable raises in
  # the LAYOUT and the page 500s before the partial runs. That is a stronger
  # fact than the other two lines carry, and it is what the message now states.
  #
  # The pair of assertions is the proof: the contract page raises, AND a page
  # that does not contain this partial at all raises identically. The second is
  # the control - without it, "the page raised" would be equally consistent with
  # the partial being the thing that failed.

  test "the cluster caption fallback cannot render, because the layout reads NETWORK first" do
    without_const(:NETWORK) do
      partial_page = assert_raises(ActionView::Template::Error) { get contract_path }
      assert_match(/NETWORK/, partial_page.message,
        "expected the NameError for the missing constant, not some unrelated view failure")

      # The failure is in the LAYOUT, before the partial is reached. Asserting
      # the partial is ABSENT from the trace is the half that matters: it is
      # what rules out "the partial raised and its own rescue failed to catch".
      trace = partial_page.backtrace.join("\n")
      assert_match(%r{layouts/application\.html\.erb}, trace,
        "expected the layout's body tag (data-solana-cluster) to be the raising frame")
      assert_no_match(/_section_admin_state/, trace,
        "the partial must never be reached - if it appears here the fallback IS reachable " \
        "and this message is wrong")

      # CONTROL: a page WITHOUT the admin card, rendered through the same
      # layout, must fail identically. root_path is a 302 that renders no
      # layout at all, so the redirect has to be FOLLOWED for this to mean
      # anything - an unfollowed 302 passes this test while proving nothing.
      no_partial_page = assert_raises(ActionView::Template::Error) do
        get root_path
        follow_redirect!
      end
      assert_match(/NETWORK/, no_partial_page.message,
        "a page WITHOUT the admin card must fail the same way - otherwise the failure is " \
        "partial-local and the fallback would be reachable after all")
    end
  end

  test "the cluster caption fallback says it is unreachable rather than inventing an error" do
    source = Rails.root.join(PARTIAL).read

    caption = source[/Solana::Config::NETWORK rescue "([^"]*)"/, 1]
    assert caption.present?,
      "could not find the NETWORK rescue in #{PARTIAL} - this guard would pass vacuously"
    assert_match(/unreachable/, caption,
      "the NETWORK fallback cannot fire (the layout reads NETWORK first). Acceptance is that a " \
      "state which cannot occur says so, rather than being dressed in a friendlier error string.")
    assert_no_match(/not set/i, caption,
      "an unset SOLANA_NETWORK raises in production by design (OPSEC-012), and since PR 559 " \
      "empty and whitespace-only do too - none of them can produce this text")
  end

  # --- the standing guard: this card's fallbacks may never blame an env var ---
  #
  # The class of defect, kept armed for fallbacks that do not exist yet. Every
  # value in this card comes from Solana::Config, and no unset variable can
  # produce a rendered fallback for any of them, so "not set" is never the true
  # cause here.

  test "no fallback in the admin card blames a missing env var" do
    source = Rails.root.join(PARTIAL).read

    fallbacks = source.scan(/rescue\s+"([^"]*)"/).flatten
    assert_equal 3, fallbacks.length,
      "expected the 3 known rescue fallbacks in #{PARTIAL}; found #{fallbacks.length}. " \
      "If a fallback was added or removed, extend this guard rather than relaxing it - " \
      "a zero-match scan would pass without reading a line."

    fallbacks.each do |text|
      assert_no_match(/not set/i, text,
        "#{PARTIAL} fallback #{text.inspect} blames an unset variable. Nothing in this card can " \
        "render with its variable unset: PROGRAM_ID and NETWORK raise during eager load in " \
        "production, and squads_vault_pda never raises. Name the load failure instead.")
      assert_match(/Solana::Config did not load|unreachable/, text,
        "#{PARTIAL} fallback #{text.inspect} must name the state that actually produces it - " \
        "a Solana::Config load failure, or, for the NETWORK caption, that it cannot fire at all")
    end
  end
end
