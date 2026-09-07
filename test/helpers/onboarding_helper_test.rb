require "test_helper"

# The pool the first-name card samples its typed placeholder from.
class OnboardingHelperTest < ActionView::TestCase
  include OnboardingHelper

  test "every entry is a plain first name" do
    # FIRST names only — the field asks for one, so the worked example has to be
    # one. A full name slipping in ("Josh Allen") would type a two-word answer
    # into a field asking for a first name, teaching the wrong thing. It is NOT
    # that the endpoint rejects the space — it accepts "Josh Allen" and derives
    # a surname from it — and this comment used to say otherwise. The space is
    # what makes the length bound below the PER-FIELD one, so this assertion and
    # that one are the same rule read twice.
    OnboardingHelper::QB_FIRST_NAMES.each do |name|
      assert_not_includes name, " ", "#{name.inspect} is not a single first name"
      assert name.present?, "blank entry in the list"
      # BOUND TO THE CAP THESE ENTRIES ACTUALLY MEET, which is not the field's
      # maxlength. Two different caps guard this endpoint, with two different
      # messages, and the assertion above decides which one applies:
      #
      #   Studio::FULL_NAME_MAX_LENGTH (81) — the WHOLE-ANSWER cap. It is the
      #     field's maxlength, and it is derived as (per-field * 2) + 1: first
      #     name, a space, surname. Past it the server answers "Please shorten
      #     that to 81 characters or fewer."
      #   Studio::FIRST_NAME_MAX_LENGTH (40) — the PER-FIELD cap, applied to
      #     each half the server derives from the answer. Past it the server
      #     answers "Please keep each name to 40 characters or fewer."
      #
      # The space assertion above proves every entry here is ONE WORD, and a
      # one-word answer derives to ONE half — so the per-field cap is the only
      # one it can ever hit. Measured against the live endpoint on engine
      # 0.70.0: 41 characters unsplit is refused per-field; 81 characters split
      # 40+1+40 is accepted; 82 split is refused whole-answer. So bounding these
      # entries at 81 would pass a 41-to-80 character placeholder the server
      # would then refuse — a guard weaker than the thing it guards.
      #
      # Hard-coding 40 would be the same mistake in the other direction: the
      # number belongs to the engine and moves with it, and Studio's own comment
      # notes that raising the per-field cap moves the whole-answer cap with it
      # BY CONSTRUCTION. Read the constant, just the right one.
      assert name.length <= Studio::FIRST_NAME_MAX_LENGTH,
             "#{name.inspect} is longer than Studio::FIRST_NAME_MAX_LENGTH " \
             "(#{Studio::FIRST_NAME_MAX_LENGTH}), the PER-FIELD cap the server applies to a " \
             "one-word answer — it would type a placeholder the endpoint then refuses with " \
             "\"Please keep each name to #{Studio::FIRST_NAME_MAX_LENGTH} characters or fewer.\""
    end
  end

  test "the pool is non-empty, because an empty one types nothing" do
    # The card falls back to 'Alex' on an empty pool rather than animating a
    # blank string, but an empty constant here would be a silent downgrade of
    # the whole feature — fail loudly instead.
    assert OnboardingHelper::QB_FIRST_NAMES.any?
    assert_equal OnboardingHelper::QB_FIRST_NAMES, first_name_placeholder_names
  end

  test "the list is frozen, so a sample can never mutate it" do
    assert OnboardingHelper::QB_FIRST_NAMES.frozen?
  end
end
