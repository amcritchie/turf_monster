# frozen_string_literal: true

require "test_helper"

# [component] Turf's own section of the living style guide.
#
# WHY THIS TIER EXISTS AT ALL. The section's whole value is that its triggers
# open the app's REAL modals rather than a mirror of them, and the way that goes
# wrong is silent: a trigger that names an id nothing registers opens an empty
# panel, and a trigger that passes a prop the card does not read simply shows the
# default state while looking correct. Neither fails loudly, so both are asserted
# here against the ids the LAYOUT registers and the props the PARTIALS read.
class StyleHostSectionTest < ActionDispatch::IntegrationTest
  # Every id this section triggers, and the prop keys it passes with each.
  # Keyed to the production partial, not to any specimen — the retired engine
  # mirrors passed `currentAddress` to wallet-changed (which reads oldAddress)
  # and offered wallet-setup a `detected` prop that exists only on the mirror.
  TRIGGERS = {
    "wallet-setup"     => %w[returnUrl],
    "wallet-changed"   => %w[oldAddress newAddress providerLabel],
    "buy-entry-token"  => [],
    # BOTH keys, and flow is the one a partial-only review cannot find: it is
    # read by an isBuy getter in shared/_alpine_factories, strictly, with no
    # default — so a step passed alone renders the cash-out arm under a card
    # labelled "buy". props.flow appears ZERO times in _cdp_ramp itself.
    "cdp-ramp"         => %w[flow step],
    "cosign-rejected"  => []
  }.freeze

  # Where a prop may legitimately be READ. The partial is the obvious place; the
  # Alpine factory is the one that made the first version of this test blind.
  PROP_SOURCES = [
    "app/views/modals/_%s.html.erb",
    "app/views/shared/_alpine_factories.html.erb"
  ].freeze

  # Ids whose registration is capability-gated, with the predicate that gates
  # them. Their card is rendered DISABLED rather than triggered, so requiring a
  # live registration would fail on any stack with the capability off.
  CAPABILITY_GATED = { "cdp-ramp" => :cdp_ramp_modal_available? }.freeze

  setup do
    log_in_as(users(:alex))
    get admin_style_path
    follow_redirect! while response.redirect?
    assert_response :success
    @body = response.body
  end

  test "the host section renders inside the gem's container" do
    assert_includes @body, 'id="host-modals"',
                    "the engine renders the section element; if this is missing the seam did not resolve"
    assert_includes @body, "app/views/style/host/_modals.html.erb",
                    "the gem's intro line names the file that contributed the section"
  end

  test "every trigger opens an id that is REGISTERED ON THE RENDERED PAGE" do
    # THIS ASSERTION USED TO READ SOURCE FILES AND IT PROVED NOTHING. It grepped
    # layouts/application.html.erb for `current().id === '<id>'` — a string that
    # is in the file whether or not its enclosing `<% if %>` ever renders. It
    # passed on cdp-ramp while that card opened an EMPTY panel, because the id is
    # registered behind cdp_ramp_modal_available? and the flag is off by default.
    #
    # modal_registration_sources scans the RENDERED body and counts <template>
    # nesting for exactly this failure. Asserting against @body is what makes the
    # guard bite.
    TRIGGERS.each_key do |id|
      gate = CAPABILITY_GATED[id]

      if gate && !ApplicationController.helpers.respond_to?(gate)
        next
      end

      blocks = modal_registration_sources(@body, id)

      if gate
        # Capability off: the card must be rendered DISABLED, not triggered.
        next if blocks.empty?
      end

      refute_empty blocks,
                   "#{id} is triggered from the host section but has NO registration on the " \
                   "rendered page — the host would open an EMPTY panel"
    end
  end

  test "a capability-gated card is disabled rather than silently dead" do
    # The honest state for a capability that is off. Without this, "no
    # registration" and "correctly greyed out" look identical to the test above.
    section = @body[@body.index('id="host-modals"')..] || ""

    CAPABILITY_GATED.each_key do |id|
      next unless modal_registration_sources(@body, id).empty?

      assert_includes section, "requires ENABLE_",
                      "#{id} has no registration on this stack, so its card must carry a " \
                      "disabled label saying why rather than offering a dead trigger"
    end
  end

  test "no trigger drives the gem's page-scoped store" do
    # dsModals is the engine section's private host. Driving it from here would
    # rebuild the mirror this section exists to replace — and it would LOOK fine,
    # because dsModals is defined on this page.
    section = @body[@body.index('id="host-modals"')..] || ""
    refute_includes section, "dsModals",
                    "a host specimen must drive the app's real $store.modals, never dsModals"
  end

  test "the props in the RENDERED trigger match the declared set, and the code reads them" do
    # TWO HALVES, because the first version had neither. It iterated TRIGGERS and
    # grepped the partial, never touching @body — so nothing asserted that the
    # markup passes those keys at all, and a mutation "proving" this guard only
    # ever reddened by editing the constant.
    TRIGGERS.each do |id, keys|
      rendered = @body[/\$store\.modals\.open\('#{Regexp.escape(id)}'(?:,\s*\{(.*?)\})?\s*\)/m, 1].to_s
      passed   = rendered.scan(/([a-zA-Z]+):/).flatten

      # A DISABLED card renders no trigger at all — which is the point of
      # disabling it, and is asserted by the capability test above. There is
      # then no markup to compare against, so half (a) does not apply; half (b)
      # still does, because the declared keys are what the card WILL pass on a
      # stack where the capability is on.
      gated_off = CAPABILITY_GATED.key?(id) && modal_registration_sources(@body, id).empty?

      unless gated_off
        # (a) the MARKUP and the constant must agree, in both directions.
        assert_equal keys.sort, passed.sort,
                     "the rendered trigger for #{id} passes #{passed.sort.inspect} but this test " \
                     "declares #{keys.sort.inspect} — one of them is wrong"
      end

      # (b) every key must be read SOMEWHERE the code actually looks.
      keys.each do |key|
        sources = PROP_SOURCES.map { |f| Rails.root.join(f.include?("%s") ? format(f, id.tr("-", "_")) : f) }
        found   = sources.any? { |f| File.exist?(f) && File.read(f).include?("props.#{key}") }

        assert found,
               "#{id} is opened with #{key}, but props.#{key} is read in none of " \
               "#{sources.map(&:basename).join(', ')} — that is specimen drift"
      end
    end
  end
end
