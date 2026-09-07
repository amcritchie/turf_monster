require "test_helper"

# MANIFEST-LEVEL CONTRACT FOR /admin/modals.
#
# The gallery and the preview layout keep SEPARATE lists: MODAL_VARIANTS says
# what to card, app/views/layouts/modal_preview.html.erb says what the preview
# iframe can actually draw. admin/modal_preview.html.erb has no dynamic
# fallback — it only calls `modals.open(cfg.id, props)` — so a card whose
# modal_id is missing from the preview layout opens an EMPTY host card, and
# empty is indistinguishable from "a modal with little in it".
#
# onboarding_gallery_test.rb found that defect on the onboarding chain and
# guarded that chain. This file holds the WHOLE-MANIFEST version of the same
# property, which /tasks/drop-dead-gallery-cards closed by deleting the cards
# that could never draw rather than by registering them.
class ModalGalleryManifestTest < ActionDispatch::IntegrationTest
  setup { @admin = users(:alex) } # role: admin

  # The ids a preview can reach, from BOTH registration sites.
  def previewable_ids
    preview = Rails.root.join("app/views/layouts/modal_preview.html.erb").read
    # cosign-rejected is registered ONCE, in modals/_host_extras, which
    # studio-engine's host renders inside its card on every path through it —
    # so a single entry reaches both layouts. Do NOT "fix" a miss below by
    # adding a second registration: modal_host_adoption_test.rb fails on the
    # duplicate, because two copies are free to drift.
    extras = Rails.root.join("app/views/modals/_host_extras.html.erb").read
    (preview + extras).scan(/id === '([^']+)'/).flatten.uniq
  end

  test "every gallery card is registered in the preview layout" do
    missing = AdminController::MODAL_VARIANTS.map { |v| v[:modal_id] }.uniq - previewable_ids

    assert_empty missing,
                 "these gallery cards have no preview registration, so /admin/modals " \
                 "draws an EMPTY card for each: #{missing.inspect}. Either register the " \
                 "modal in app/views/layouts/modal_preview.html.erb or drop its card."
  end

  test "the gallery no longer cards the templates or the unpreviewable quest chain" do
    log_in_as(@admin)
    get admin_modals_path
    assert_response :success

    # The five Templates cards rendered studio/modals/templates/* — the gem's
    # OWN partials — which studio-engine cards itself on /style#modals. No app
    # code opened them; the gallery was their only caller.
    assert_select "h2", text: "Templates", count: 0
    # The six Quest / Newsletter cards were registered in layouts/application
    # but never in the preview layout, so every one of them drew blank here.
    # All six stay carded on the engine style guide (newsletter-subscribe as
    # 'join-newsletter', newsletter-success as 'ds-newsletter-success').
    assert_select "h2", text: "Quest / Newsletter", count: 0

    # A mistyped flow step key renders this instead of a step; the deletions
    # must not have orphaned a MODAL_FLOWS reference.
    assert_not_includes response.body, "MISSING VARIANT"
  end
end
