require "test_helper"

class WalletSessionsControllerTest < ActionDispatch::IntegrationTest
  test "nonce returns json with nonce" do
    get auth_wallet_nonce_path
    assert_response :success
    json = JSON.parse(response.body)
    assert json["nonce"].present?
  end

  test "nonce returns different values each time" do
    get auth_wallet_nonce_path
    nonce1 = JSON.parse(response.body)["nonce"]
    get auth_wallet_nonce_path
    nonce2 = JSON.parse(response.body)["nonce"]
    assert_not_equal nonce1, nonce2
  end
end
