require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "display_name returns name when present" do
    user = users(:alex)
    assert_equal "Alex", user.display_name
  end

  test "display_name returns capitalized email prefix when name is blank" do
    user = User.create!(email: "newplayer@turf.com", password: "pass", balance_cents: 0)
    assert_equal "Newplayer", user.display_name
  end

  test "authenticate with correct password" do
    user = users(:alex)
    assert user.authenticate("pass")
  end

  test "authenticate with wrong password" do
    user = users(:alex)
    assert_not user.authenticate("wrong")
  end
end
