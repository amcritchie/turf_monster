require "test_helper"

class DraftPickTest < ActiveSupport::TestCase
  setup do
    @user = users(:sam)
    @contest = contests(:one)
    @picks_hash = { props(:one).id.to_s => "more", props(:two).id.to_s => "less" }
  end

  test "save_draft creates new record" do
    assert_difference "DraftPick.count", 1 do
      draft = DraftPick.save_draft(@user, @contest, @picks_hash)
      assert_equal @picks_hash, draft.picks
      assert_equal @user, draft.user
      assert_equal @contest, draft.contest
    end
  end

  test "save_draft updates existing record (upsert)" do
    DraftPick.save_draft(@user, @contest, @picks_hash)

    new_picks = { props(:three).id.to_s => "more" }
    assert_no_difference "DraftPick.count" do
      draft = DraftPick.save_draft(@user, @contest, new_picks)
      assert_equal new_picks, draft.picks
    end
  end

  test "save_draft with empty hash clears draft" do
    DraftPick.save_draft(@user, @contest, @picks_hash)

    assert_difference "DraftPick.count", -1 do
      result = DraftPick.save_draft(@user, @contest, {})
      assert_nil result
    end
  end

  test "load_draft returns draft when present" do
    DraftPick.save_draft(@user, @contest, @picks_hash)
    draft = DraftPick.load_draft(@user, @contest)
    assert_equal @picks_hash, draft.picks
  end

  test "load_draft returns nil when absent" do
    assert_nil DraftPick.load_draft(@user, @contest)
  end

  test "clear_draft removes record" do
    DraftPick.save_draft(@user, @contest, @picks_hash)

    assert_difference "DraftPick.count", -1 do
      DraftPick.clear_draft(@user, @contest)
    end
  end

  test "uniqueness of user and contest" do
    DraftPick.save_draft(@user, @contest, @picks_hash)

    duplicate = DraftPick.new(user: @user, contest: @contest, picks: {})
    assert_not duplicate.valid?
  end
end
