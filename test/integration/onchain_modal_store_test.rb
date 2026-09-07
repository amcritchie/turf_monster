require "test_helper"

# The solanaModal store's STEP contract, pinned at the layout that ships it.
#
# READ THIS BEFORE TRUSTING IT. These are String assertions against rendered
# markup, and a String cannot watch a store run — the page bytes are identical
# whether show() pushes a new modal or patches the open one. The behavioural
# evidence for that lives in e2e/onchain_modal_steps.spec.js, which drives the
# real store in a real browser and is the test that actually failed when this
# bug was introduced.
#
# What THIS test is for is narrower and still worth having: the store is inline
# in the layout, so it has no unit surface of its own, and these assertions
# catch the structural regressions a reviewer would otherwise have to spot by
# eye — the store vanishing from the layout, or show() going back to opening a
# modal unconditionally.
class OnchainModalStoreTest < ActionDispatch::IntegrationTest
  setup do
    # root redirects to the featured contest; /contests renders the layout
    # directly, which is all this test needs.
    get contests_path
    assert_response :success
    @body = response.body
  end

  test "the layout ships the solanaModal store" do
    assert_match(/Alpine\.store\('solanaModal'/, @body)
  end

  test "show patches an already-open onchain modal instead of opening another" do
    # The guard is the fix: an open, not-closing onchain-tx entry gets its props
    # patched and show() returns before it can reach open().
    assert_match(/if \(current && !current\._closing\) \{/, @body,
      "show() no longer guards on an already-open modal — every step would push a new one")
    assert_match(/Object\.assign\(current\.props, props\)/, @body,
      "show() no longer patches the open modal in place")
  end

  test "the store opens an onchain modal from exactly one place" do
    # Two open() call sites is how the stack grows back: one for the first step
    # is correct, a second for subsequent steps is the bug.
    opens = @body.scan(/Alpine\.store\('modals'\)\.open\('onchain-tx'/).length
    assert_equal 1, opens, "expected a single open('onchain-tx') call site, found #{opens}"
  end

  test "a step resets the transient props so a retry cannot show a stale failure" do
    step_props = @body[/_stepProps: function\(title, message\) \{.*?\n            \},/m]
    assert step_props, "_stepProps is gone — steps no longer share one prop shape"
    assert_match(/errorMessage:\s*null/, step_props)
    assert_match(/txSignature:\s*null/, step_props)
    assert_match(/state:\s*'processing'/, step_props)
  end
end
