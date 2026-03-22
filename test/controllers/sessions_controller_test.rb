require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login page renders" do
    get login_path
    assert_response :success
  end

  test "login with valid credentials" do
    log_in_as users(:alex)
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "login with bad password" do
    post login_path, params: { email: "alex@turf.com", password: "wrong" }
    assert_response :unprocessable_entity
  end

  test "logout clears session" do
    log_in_as users(:alex)
    get logout_path
    assert_redirected_to login_path
  end
end
