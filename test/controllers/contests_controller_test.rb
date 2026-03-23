require "test_helper"

class ContestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @prop1 = props(:one)
    @prop2 = props(:two)
    @prop3 = props(:three)
  end

  # --- toggle_pick tests ---

  test "toggle_pick creates entry and pick on first toggle" do
    log_in_as(@user)

    assert_difference ["Entry.count", "Pick.count"], 1 do
      post toggle_pick_contest_path(@contest),
        params: { prop_id: @prop1.id, selection: "more" },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal({ @prop1.id.to_s => "more" }, json["picks"])
    assert_equal 1, json["pick_count"]
  end

  test "toggle_pick removes pick when same selection toggled" do
    log_in_as(@user)

    # Create a cart entry with one pick
    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")

    assert_difference "Pick.count", -1 do
      post toggle_pick_contest_path(@contest),
        params: { prop_id: @prop1.id, selection: "more" },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal({}, json["picks"])
    assert_equal 0, json["pick_count"]
    # Entry should be destroyed when empty
    assert_not Entry.exists?(entry.id)
  end

  test "toggle_pick switches selection" do
    log_in_as(@user)

    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")

    assert_no_difference "Pick.count" do
      post toggle_pick_contest_path(@contest),
        params: { prop_id: @prop1.id, selection: "less" },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "less", json["picks"][@prop1.id.to_s]
  end

  test "toggle_pick replaces newest pick when adding 4th" do
    log_in_as(@user)

    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")
    entry.picks.create!(prop: @prop3, selection: "more")

    prop4 = @contest.props.create!(description: "France Total Goals", line: 1.5, stat_type: "goals", status: "pending")

    post toggle_pick_contest_path(@contest),
      params: { prop_id: prop4.id, selection: "more" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 3, json["pick_count"]
    assert json["picks"].key?(prop4.id.to_s)
    assert_not json["picks"].key?(@prop3.id.to_s)
  end

  test "toggle_pick allows picks after confirming an entry" do
    log_in_as(@user)

    # Sam already has an active entry
    entry = @contest.entries.create!(user: @user, status: :active)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")
    entry.picks.create!(prop: @prop3, selection: "more")

    assert_difference "Entry.count", 1 do
      post toggle_pick_contest_path(@contest),
        params: { prop_id: @prop1.id, selection: "more" },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal({ @prop1.id.to_s => "more" }, json["picks"])
    # New cart entry created separate from the active one
    new_entry = @contest.entries.cart.find_by(user: @user)
    assert_not_equal entry.id, new_entry.id
  end

  test "toggle_pick requires authentication" do
    post toggle_pick_contest_path(@contest),
      params: { prop_id: @prop1.id, selection: "more" },
      as: :json

    assert_response :redirect
    assert_redirected_to login_path
  end

  # --- enter (confirm) tests ---

  test "enter confirms cart entry with JSON" do
    log_in_as(@user)

    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")
    entry.picks.create!(prop: @prop3, selection: "more")

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

  test "enter with JSON returns error when no cart entry" do
    log_in_as(@user)

    post enter_contest_path(@contest),
      headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
  end

  test "enter requires authentication" do
    post enter_contest_path(@contest)

    assert_response :redirect
    assert_redirected_to login_path
  end

  test "enter with HTML redirects on success" do
    log_in_as(@user)

    entry = @contest.entries.create!(user: @user, status: :cart)
    entry.picks.create!(prop: @prop1, selection: "more")
    entry.picks.create!(prop: @prop2, selection: "less")
    entry.picks.create!(prop: @prop3, selection: "more")

    post enter_contest_path(@contest)

    assert_response :redirect
    assert_redirected_to root_path
  end
end
