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
    "cdp-ramp"         => %w[step],
    "cosign-rejected"  => []
  }.freeze

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

  test "every trigger names an id the app actually registers" do
    # TWO registration surfaces, and checking only the first is a trap this very
    # test fell into on its first run. Per-callsite cards live in the layout's
    # own list; a card that belongs to the APP rather than to a page lives in
    # modals/_host_extras, which the engine host renders on EVERY path through
    # it. cosign-rejected is the occupant, so a layout-only assertion reports it
    # as unregistered while it is in fact reachable everywhere.
    registrations = [
      Rails.root.join("app/views/layouts/application.html.erb"),
      Rails.root.join("app/views/modals/_host_extras.html.erb")
    ].map { |f| File.read(f) }.join("\n")

    TRIGGERS.each_key do |id|
      assert_includes @body, "$store.modals.open('#{id}'",
                      "#{id} should be triggered from the host section"
      # The id must be REGISTERED somewhere, or the real host opens an empty
      # panel — the failure the seam's contract warns about, and one that is
      # invisible in a rendered page: the card opens, and it is blank.
      assert_includes registrations, "current().id === '#{id}'",
                      "#{id} is triggered but neither the application layout nor modals/_host_extras " \
                      "registers it — the host would open an EMPTY panel"
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

  test "every prop passed is one the production partial actually reads" do
    TRIGGERS.each do |id, keys|
      next if keys.empty?

      partial = Rails.root.join("app/views/modals/_#{id.tr('-', '_')}.html.erb")
      source  = File.read(partial)

      keys.each do |key|
        assert_includes source, "props.#{key}",
                        "the host section passes #{key} to #{id}, but #{partial.basename} never reads " \
                        "props.#{key} — that is specimen drift, the exact defect this section retires"
      end
    end
  end
end
