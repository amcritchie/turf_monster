require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signup page renders" do
    get signup_path
    assert_response :success
  end

  test "signup with valid info" do
    assert_difference "User.count", 1 do
      post signup_path, params: { user: { email: "new@turf.com", password: "pass", password_confirmation: "pass" } }
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "signup with mismatched password" do
    assert_no_difference "User.count" do
      post signup_path, params: { user: { email: "new@turf.com", password: "pass", password_confirmation: "wrong" } }
    end
    assert_response :unprocessable_entity
  end
end
