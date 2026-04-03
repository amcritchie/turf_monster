require "test_helper"

class EntryTest < ActiveSupport::TestCase
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @m1 = slate_matchups(:m1)
    @m2 = slate_matchups(:m2)
    @m3 = slate_matchups(:m3)
    @m4 = slate_matchups(:m4)
    @m5 = slate_matchups(:m5)
    @m6 = slate_matchups(:m6)
  end

  test "confirm! charges fee and sets status to active" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry.selections.create!(slate_matchup: m) }

    balance_before = @user.balance_cents
    entry.confirm!

    assert entry.active?
    assert_equal balance_before - @contest.entry_fee_cents, @user.reload.balance_cents
  end

  test "confirm! rejects with less than 5 selections" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2].each { |m| entry.selections.create!(slate_matchup: m) }

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_match(/selections required/, error.message)
    assert entry.reload.cart?
  end

  test "confirm! rejects for non-open contest" do
    @contest.update!(status: "locked")
    entry = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry.selections.create!(slate_matchup: m) }

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Contest is not open", error.message
  end

  test "confirm! rejects with insufficient funds" do
    @user.update!(balance_cents: 0, promotional_cents: 0)
    entry = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry.selections.create!(slate_matchup: m) }

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Insufficient funds", error.message
  end

  # --- toggle_selection! tests ---

  test "toggle_selection! creates a new selection" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    selections_hash = entry.toggle_selection!(@m1)

    assert_equal({ @m1.id.to_s => true }, selections_hash)
    assert_equal 1, entry.selections.count
  end

  test "toggle_selection! removes selection when toggled again" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.selections.create!(slate_matchup: @m1)

    result = entry.toggle_selection!(@m1)

    assert_nil result
    assert_not Entry.exists?(entry.id)
  end

  test "confirm! rejects duplicate selection combo (sybil check)" do
    # First entry
    entry1 = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry1.selections.create!(slate_matchup: m) }
    entry1.confirm!

    # Second entry with same combo
    entry2 = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry2.selections.create!(slate_matchup: m) }

    error = assert_raises(RuntimeError) { entry2.confirm! }
    assert_match(/already have an entry/, error.message)
  end

  # --- slug test ---

  test "slug includes id after creation" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.reload
    assert_includes entry.slug, entry.id.to_s
  end

  test "to_param returns slug" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.reload
    assert_equal entry.slug, entry.to_param
  end

  test "confirm! rejects when a game has already started" do
    # Link m1 to a past game (kickoff in the past = locked)
    @m1.update!(game_slug: "past-game")

    entry = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry.selections.create!(slate_matchup: m) }

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_match(/already started/, error.message)
    assert entry.reload.cart?
  end
end
