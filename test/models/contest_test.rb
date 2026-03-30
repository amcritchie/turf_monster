require "test_helper"

class ContestTest < ActiveSupport::TestCase
  setup do
    @contest = contests(:one)
    @user = users(:sam)
  end

  test "pool_cents only counts active and complete entries" do
    # Fixtures have 2 active entries
    assert_equal 2 * @contest.entry_fee_cents, @contest.pool_cents

    # Cart entry should not count
    @contest.entries.create!(user: @user, status: :cart)
    assert_equal 2 * @contest.entry_fee_cents, @contest.pool_cents
  end

  test "picks_required returns 5" do
    assert_equal 5, @contest.picks_required
  end

  test "slug is set on save" do
    @contest.save!
    assert_equal "test-contest", @contest.slug
  end
end
