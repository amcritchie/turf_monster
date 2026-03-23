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
    entry.picks.create!(prop: @prop3, selection: "more")

    balance_before = @user.balance_cents
    entry.confirm!

    assert entry.active?
    assert_equal balance_before - @contest.entry_fee_cents, @user.reload.balance_cents
  end

  test "confirm! rejects with less than 3 picks" do
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Exactly 3 picks required", error.message
    assert entry.reload.cart?
  end

  test "confirm! rejects for non-open contest" do
    @contest.update!(status: "locked")
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")
    entry.picks.create!(prop: @prop3, selection: "more")

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Contest is not open", error.message
  end

  test "confirm! rejects with insufficient funds" do
    @user.update!(balance_cents: 0)
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")
    entry.picks.create!(prop: @prop3, selection: "more")

    error = assert_raises(RuntimeError) { entry.confirm! }
    assert_equal "Insufficient funds", error.message
  end
end
