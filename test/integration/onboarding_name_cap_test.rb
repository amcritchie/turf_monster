require "test_helper"

# The onboarding first-name field's length cap, asserted against RENDERED HTML.
#
# THE BUG THIS REGRESSES. app/views/modals/_onboarding.html.erb hard-coded
# maxlength="40". That number is Studio::FIRST_NAME_MAX_LENGTH — the PER-FIELD
# cap, what one derived half may be — and this field asks for a whole name.
# "Bartholomew Fitzwilliam Montgomery-Smythe" is 41 characters, so the browser
# clamped it to a LEGAL 40-character answer whose two halves both fit the
# per-field cap. The server therefore had nothing to refuse: 200 OK, and the
# account was handed back its own surname misspelled as "Montgomery-Smyth".
# Nothing raised, nothing logged, no 422 — the name was gone before the request
# was made. studio-engine PR #275 fixed the shared partial, but this app renders
# its OWN onboarding modal (layouts/application.html.erb registers
# render "modals/onboarding"), so the fix never reached here.
#
# WHY THESE ASSERTIONS ARE RENDERED, NOT GREPPED. The guards that already exist
# around this modal read the .erb file as a STRING (see onboarding_gallery_test's
# x-data check, which has to work that way). A source grep is documentary: it
# passes on a view that has stopped emitting the attribute at all, and it passes
# on a view whose ERB raises before reaching it. Measured before this file was
# written — there was no rendered maxlength assertion anywhere in this suite, so
# the attribute could be deleted outright and the suite stayed green. Both tests
# below therefore parse the real response body and read the real attribute off
# the real element.
#
# WHY NO NUMBER APPEARS BELOW. Neither test names 40 or 81. The first compares
# the rendered attribute to the engine constant, so an engine that moves the cap
# moves both sides together. The second compares the rendered attribute to what
# the endpoint MEASURABLY does with a name of that length, so it reads both
# bounds live. Neither can deadlock a studio-engine release — the deliberate
# property that made onboarding_controller_test drop its own length assertions.
class OnboardingNameCapTest < ActionDispatch::IntegrationTest
  # The modal as a browser receives it. /admin/modals/preview is the path
  # onboarding_gallery_test already uses to render this card, and it goes
  # through modal_preview.html.erb's registration — the same
  # render "modals/onboarding" the application layout performs.
  def rendered_first_name_field
    log_in_as users(:alex)
    get admin_modal_preview_path(modal_id: "onboarding", props: {}.to_json)
    assert_response :success

    field = Nokogiri::HTML(response.body).at_css("#onboarding-first-name")
    assert field, "the first-name input did not render at all"
    field
  end

  # --- [component] the rendered bound -----------------------------------------

  test "the rendered first-name field caps at the WHOLE-ANSWER length" do
    field = rendered_first_name_field

    # Present at all. Read explicitly rather than folded into the comparison
    # below, because a missing attribute and a wrong one are different bugs and
    # the failure message should say which happened.
    assert field["maxlength"].present?,
           "the field renders no maxlength — the browser would accept any length, " \
           "and this assertion exists because deleting the attribute used to be invisible"

    # Bound to the constant, not to a copy of its value. Studio derives
    # FULL_NAME_MAX_LENGTH as first(FIRST_NAME_MAX_LENGTH) + a space +
    # last(FIRST_NAME_MAX_LENGTH), so it is the longest answer whose two halves
    # both still fit the per-field cap — onboarding can never accept a name
    # /profile would later shorten. Comparing against the constant means a
    # re-hardcoded literal passes today and goes red the moment the engine moves
    # the cap, which is precisely when the drift starts costing names.
    assert_equal Studio::FULL_NAME_MAX_LENGTH.to_s, field["maxlength"],
                 "the field must read Studio::FULL_NAME_MAX_LENGTH. " \
                 "Studio::FIRST_NAME_MAX_LENGTH (#{Studio::FIRST_NAME_MAX_LENGTH}) is a different " \
                 "question — what ONE derived half may be — and using it here is the bug " \
                 "that truncated Montgomery-Smythe"
  end

  # --- [integration] the two bounds agree -------------------------------------

  test "what the browser allows is exactly what the endpoint accepts" do
    cap = rendered_first_name_field["maxlength"].to_i
    assert cap.positive?, "no rendered cap to measure the server against"

    user = users(:jordan)
    user.update_columns(first_name: nil, name: nil)
    log_in_as user

    # A name of EXACTLY the rendered length, split so both halves clear the
    # per-field cap — otherwise the endpoint's second guard fires and this would
    # measure the wrong rule.
    half = (cap - 1) / 2
    at_cap = "#{'a' * half} #{'b' * (cap - 1 - half)}"
    assert_equal cap, at_cap.length

    post onboarding_first_name_path, params: { first_name: at_cap }, as: :json
    assert_response :success,
                    "the browser let this through, so the server must not lose it — " \
                    "a browser bound TIGHTER than the server is how the name vanished silently"
    assert_equal at_cap, user.reload.name,
                 "stored in full — the whole point is that nothing is quietly shortened"

    # And one character past it is refused rather than truncated, so the browser
    # bound is not looser than the server's either.
    post onboarding_first_name_path, params: { first_name: "#{at_cap}c" }, as: :json
    assert_response :unprocessable_entity,
                    "past the rendered cap the server must refuse, not rewrite the answer"
    assert_equal at_cap, user.reload.name, "the refused answer must not have overwritten the stored one"
  end

  # THE OTHER GUARD, which the test above deliberately steers around. Its
  # comment says so: it splits its answer "so both halves clear the per-field
  # cap — otherwise the endpoint's SECOND guard fires and this would measure the
  # wrong rule." That second guard was therefore never measured here at all, and
  # something now depends on it: test/helpers/onboarding_helper_test.rb bounds
  # every typed placeholder by Studio::FIRST_NAME_MAX_LENGTH, on the grounds
  # that a ONE-WORD answer derives to one half and can only ever meet the
  # per-field cap. That is a claim about this endpoint, so this asserts it here
  # rather than leaving it as reasoning in a comment two files away.
  #
  # It is also the assertion that keeps the two caps from being confused again.
  # An unsplit answer one character past the per-field cap is still far BELOW
  # the whole-answer cap, so a 422 alone would not say which rule fired — the
  # message is what distinguishes them, and both are read off the constants so
  # no number is written down here either.
  test "a one-word answer is bounded by the per-field cap, not the whole-answer cap" do
    user = users(:jordan)
    user.update_columns(first_name: nil, name: nil)
    log_in_as user

    at_cap = "a" * Studio::FIRST_NAME_MAX_LENGTH

    post onboarding_first_name_path, params: { first_name: at_cap }, as: :json
    assert_response :success,
                    "a single word of exactly Studio::FIRST_NAME_MAX_LENGTH must be accepted — " \
                    "it is the longest one-word answer the endpoint can store"
    assert_equal at_cap, user.reload.name, "stored in full, not shortened"

    over = "#{at_cap}a"
    assert_operator over.length, :<, Studio::FULL_NAME_MAX_LENGTH,
                    "this probe has to sit BELOW the whole-answer cap, or it would be measuring " \
                    "that guard instead of the per-field one"

    post onboarding_first_name_path, params: { first_name: over }, as: :json
    assert_response :unprocessable_entity,
                    "one word past the per-field cap must be refused even though it is well " \
                    "under the whole-answer cap — that is the whole difference between the two"

    error = response.parsed_body["error"].to_s
    assert_includes error, Studio::FIRST_NAME_MAX_LENGTH.to_s,
                    "the refusal must name the PER-FIELD cap (#{Studio::FIRST_NAME_MAX_LENGTH}); " \
                    "it said #{error.inspect}"
    assert_not_includes error, Studio::FULL_NAME_MAX_LENGTH.to_s,
                    "the whole-answer cap (#{Studio::FULL_NAME_MAX_LENGTH}) is NOT the rule that " \
                    "fired here — if it is, a one-word placeholder bounded at the per-field cap " \
                    "is bounded by the wrong constant"
    assert_equal at_cap, user.reload.name, "the refused answer must not have overwritten the stored one"
  end
end
