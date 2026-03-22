require "test_helper"

class ContestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contest = contests(:one)
    @user = users(:sam)
    @prop1 = props(:one)
    @prop2 = props(:two)
    @prop3 = props(:three)
  end

  test "enter with JSON returns success" do
    log_in_as(@user)

    post enter_contest_path(@contest),
      params: { picks: { @prop1.id.to_s => "more", @prop2.id.to_s => "less", @prop3.id.to_s => "more" } },
      headers: { "Accept" => "application/json" }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["redirect"]
  end

  test "enter with JSON returns error on validation failure" do
    log_in_as(@user)

    post enter_contest_path(@contest),
      params: { picks: { @prop1.id.to_s => "more" } },
      headers: { "Accept" => "application/json" }

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_not json["success"]
    assert_equal "Exactly 3 picks required", json["error"]
  end

  test "enter requires authentication" do
    post enter_contest_path(@contest),
      params: { picks: { @prop1.id.to_s => "more", @prop2.id.to_s => "less", @prop3.id.to_s => "more" } }

    assert_response :redirect
    assert_redirected_to login_path
  end

  test "enter with HTML redirects on success" do
    log_in_as(@user)

    post enter_contest_path(@contest),
      params: { picks: { @prop1.id.to_s => "more", @prop2.id.to_s => "less", @prop3.id.to_s => "more" } }

    assert_response :redirect
    assert_redirected_to root_path
  end

  test "enter with HTML redirects with alert on error" do
    log_in_as(@user)

    post enter_contest_path(@contest),
      params: { picks: { @prop1.id.to_s => "more" } }

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal "Exactly 3 picks required", flash[:alert]
  end
end
