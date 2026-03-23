require "test_helper"

class DraftPicksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @prop1 = props(:one)
    @prop2 = props(:two)
    @prop3 = props(:three)
    @picks_hash = { @prop1.id.to_s => "more", @prop2.id.to_s => "less" }
  end

  test "show returns empty when no draft" do
    log_in_as(@user)
    get contest_draft_picks_path(@contest), headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_empty json
  end

  test "show returns saved draft" do
    log_in_as(@user)
    DraftPick.save_draft(@user, @contest, @picks_hash)

    get contest_draft_picks_path(@contest), headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @picks_hash, json["picks"]
    assert json["updated_at"].present?
  end

  test "update saves draft picks" do
    log_in_as(@user)

    assert_difference "DraftPick.count", 1 do
      patch contest_draft_picks_path(@contest),
        params: { picks: @picks_hash },
        headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @picks_hash, json["picks"]
  end

  test "update rejects for non-open contest" do
    @contest.update!(status: "locked")
    log_in_as(@user)

    patch contest_draft_picks_path(@contest),
      params: { picks: @picks_hash },
      headers: { "Accept" => "application/json" },
      as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Contest is not open", json["error"]
  end

  test "update rejects if user already entered" do
    log_in_as(@user)
    @contest.enter!(@user, { @prop1.id.to_s => "more", @prop2.id.to_s => "less", @prop3.id.to_s => "more" })

    patch contest_draft_picks_path(@contest),
      params: { picks: @picks_hash },
      headers: { "Accept" => "application/json" },
      as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "Already entered", json["error"]
  end

  test "show requires authentication" do
    get contest_draft_picks_path(@contest), headers: { "Accept" => "application/json" }
    assert_response :redirect
    assert_redirected_to login_path
  end

  test "beacon saves draft via POST" do
    log_in_as(@user)

    assert_difference "DraftPick.count", 1 do
      post beacon_contest_draft_picks_path(@contest),
        params: { picks: @picks_hash },
        as: :json
    end

    assert_response :ok
    draft = DraftPick.load_draft(@user, @contest)
    assert_equal @picks_hash, draft.picks
  end
end
