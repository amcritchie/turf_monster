require "test_helper"

class ContestTest < ActiveSupport::TestCase
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @prop1 = props(:one)
    @prop2 = props(:two)
    @prop3 = props(:three)
  end

  test "enter! requires exactly 3 picks" do
    # Too few picks (2)
    error = assert_raises(RuntimeError) do
      @contest.enter!(@user, { @prop1.id.to_s => "more", @prop2.id.to_s => "less" })
    end
    assert_equal "Exactly 3 picks required", error.message
  end

  test "enter! rejects more than 3 picks" do
    # Need a 4th prop
    prop4 = @contest.props.create!(description: "France Total Goals", line: 1.5, stat_type: "goals", status: "pending")

    error = assert_raises(RuntimeError) do
      @contest.enter!(@user, {
        @prop1.id.to_s => "more",
        @prop2.id.to_s => "less",
        @prop3.id.to_s => "more",
        prop4.id.to_s => "less"
      })
    end
    assert_equal "Exactly 3 picks required", error.message
  end

  test "enter! accepts exactly 3 picks" do
    entry = @contest.enter!(@user, {
      @prop1.id.to_s => "more",
      @prop2.id.to_s => "less",
      @prop3.id.to_s => "more"
    })

    assert entry.persisted?
    assert_equal 3, entry.picks.count
  end

  test "enter! ignores blank pick values when counting" do
    error = assert_raises(RuntimeError) do
      @contest.enter!(@user, {
        @prop1.id.to_s => "more",
        @prop2.id.to_s => "less",
        @prop3.id.to_s => ""
      })
    end
    assert_equal "Exactly 3 picks required", error.message
  end
end
