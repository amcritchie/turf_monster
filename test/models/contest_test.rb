require "test_helper"

class ContestTest < ActiveSupport::TestCase
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @prop1 = props(:one)
    @prop2 = props(:two)
    @prop3 = props(:three)
  end

  test "pool_cents only counts active and complete entries" do
    # Fixtures have 2 active entries
    assert_equal 2 * @contest.entry_fee_cents, @contest.pool_cents

    # Cart entry should not count
    @contest.entries.create!(user: @user, status: :cart)
    assert_equal 2 * @contest.entry_fee_cents, @contest.pool_cents
  end

  test "grade! transitions active entries to complete" do
    @prop1.update!(result_value: 2.0)
    @prop2.update!(result_value: 1.0)
    @prop3.update!(result_value: 3.0)

    @contest.grade!

    @contest.entries.each do |entry|
      assert entry.complete?, "Expected entry to be complete but was #{entry.status}"
    end
    assert @contest.settled?
  end

  test "grade! ignores cart entries" do
    cart_entry = @contest.entries.create!(user: @user, status: :cart)
    cart_entry.picks.create!(prop: @prop1, selection: "more")

    @prop1.update!(result_value: 2.0)
    @prop2.update!(result_value: 1.0)
    @prop3.update!(result_value: 3.0)

    @contest.grade!

    assert cart_entry.reload.cart?, "Cart entry should remain cart after grading"
  end

  test "slug is set on save" do
    @contest.save!
    assert_equal "test-contest", @contest.slug
  end
end
