require "test_helper"

class ContestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @m1 = contest_matchups(:m1)
    @m2 = contest_matchups(:m2)
    @m3 = contest_matchups(:m3)
    @m4 = contest_matchups(:m4)
    @m5 = contest_matchups(:m5)
    @m6 = contest_matchups(:m6)
  end

  # --- toggle_selection tests ---

  test "toggle_selection creates entry and selection on first toggle" do
    log_in_as(@user)

    assert_difference ["Entry.count", "Selection.count"], 1 do
      post toggle_selection_contest_path(@contest),
        params: { matchup_id: @m1.id },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal({ @m1.id.to_s => true }, json["selections"])
    assert_equal 1, json["selection_count"]
  end

  test "toggle_selection removes selection when toggled again" do
    log_in_as(@user)

    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.selections.create!(contest_matchup: @m1)

    assert_difference "Selection.count", -1 do
      post toggle_selection_contest_path(@contest),
        params: { matchup_id: @m1.id },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal({}, json["selections"])
    assert_equal 0, json["selection_count"]
    # Entry should be destroyed when empty
    assert_not Entry.exists?(entry.id)
  end

  test "toggle_selection requires authentication" do
    post toggle_selection_contest_path(@contest),
      params: { matchup_id: @m1.id },
      as: :json

    assert_response :redirect
    assert_redirected_to login_path
  end

  # --- enter (confirm) tests ---

  test "enter confirms cart entry with JSON" do
    log_in_as(@user)

    entry = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry.selections.create!(contest_matchup: m) }

    balance_before = @user.balance_cents

    post enter_contest_path(@contest),
      headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["redirect"]
    assert entry.reload.active?
    assert_equal balance_before - @contest.entry_fee_cents, @user.reload.balance_cents
  end

  test "enter with JSON redirects when no cart entry" do
    log_in_as(@user)

    post enter_contest_path(@contest),
      headers: { "Accept" => "application/json" }

    assert_response :redirect
  end

  test "enter requires authentication" do
    post enter_contest_path(@contest)

    assert_response :redirect
    assert_redirected_to login_path
  end

  test "enter with HTML redirects on success" do
    log_in_as(@user)

    entry = @contest.entries.create!(user: @user, status: :cart)
    [@m1, @m2, @m3, @m4, @m5].each { |m| entry.selections.create!(contest_matchup: m) }

    post enter_contest_path(@contest)

    assert_response :redirect
    assert_redirected_to contest_path(@contest)
  end

  # --- page load tests ---

  test "index loads" do
    get root_path
    assert_response :success
  end

  test "show loads" do
    get contest_path(@contest)
    assert_response :success
  end
end
