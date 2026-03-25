require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alex = users(:alex)
  end

  test "show requires login" do
    get account_path
    assert_redirected_to login_path
  end

  test "show renders for logged in user" do
    log_in_as @alex
    get account_path
    assert_response :success
  end

  test "update changes name" do
    log_in_as @alex
    patch account_path, params: { user: { name: "New Name" } }
    assert_redirected_to account_path
    @alex.reload
    assert_equal "New Name", @alex.name
  end

  test "unlink_google clears provider and uid" do
    @alex.update!(provider: "google_oauth2", uid: "12345")
    log_in_as @alex
    post unlink_google_account_path
    assert_redirected_to account_path
    @alex.reload
    assert_nil @alex.provider
    assert_nil @alex.uid
  end

  test "change_password updates password" do
    log_in_as @alex
    post change_password_account_path, params: {
      current_password: "password",
      new_password: "newpassword",
      new_password_confirmation: "newpassword"
    }
    assert_redirected_to account_path
    @alex.reload
    assert @alex.authenticate("newpassword")
  end

  test "change_password fails with wrong current password" do
    log_in_as @alex
    post change_password_account_path, params: {
      current_password: "wrongpassword",
      new_password: "newpassword",
      new_password_confirmation: "newpassword"
    }
    assert_response :unprocessable_entity
  end
end
