require "test_helper"

class EntryTest < ActiveSupport::TestCase
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @prop1 = props(:one)
    @prop2 = props(:two)
    @prop3 = props(:three)
  end

  test "confirm! charges fee and sets status to active" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")

    balance_before = @user.balance_cents
    entry.confirm!

    assert entry.active?
    assert_equal balance_before - @contest.entry_fee_cents, @user.reload.balance_cents
  end

  test "confirm! rejects with less than 2 picks" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Exactly 2 picks required", error.message
    assert entry.reload.cart?
  end

  test "confirm! rejects for non-open contest" do
    @contest.update!(status: "locked")
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Contest is not open", error.message
  end

  test "confirm! rejects with insufficient funds" do
    @user.update!(balance_cents: 0)
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Insufficient funds", error.message
  end

  # --- toggle_pick! tests ---

  test "toggle_pick! creates a new pick" do
    entry = @contest.entries.create!(user: @user, status: :cart)

    picks_hash = entry.toggle_pick!(@prop1, "more")

    assert_equal({ @prop1.id.to_s => "more" }, picks_hash)
    assert_equal 1, entry.picks.count
  end

  test "toggle_pick! removes pick when same selection" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")

    result = entry.toggle_pick!(@prop1, "more")

    assert_nil result
    assert_not Entry.exists?(entry.id)
  end

  test "toggle_pick! switches selection" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")

    picks_hash = entry.toggle_pick!(@prop1, "less")

    assert_equal "less", picks_hash[@prop1.id.to_s]
    assert_equal 1, entry.picks.count
  end

  test "toggle_pick! replaces newest pick when adding 3rd" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")

    picks_hash = entry.toggle_pick!(@prop3, "more")

    assert_equal 2, entry.picks.count
    assert_includes picks_hash.keys, @prop3.id.to_s
    assert_not_includes picks_hash.keys, @prop2.id.to_s
  end

  test "toggle_pick! destroys entry when last pick removed" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")

    result = entry.toggle_pick!(@prop1, "more")

    assert_nil result
    assert_not Entry.exists?(entry.id)
  end

  # --- slug test ---

  test "slug is set on save" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.reload
    assert_equal "sam-test-contest-#{entry.id}", entry.slug
  end
end
