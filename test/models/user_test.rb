require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "display_name returns name when present" do
    user = users(:alex)
    assert_equal "Alex", user.display_name
  end

  test "display_name returns capitalized email prefix when name is blank" do
    user = User.create!(email: "newplayer@turf.com", password: "password", balance_cents: 0)
    assert_equal "Newplayer", user.display_name
  end

  test "authenticate with correct password" do
    user = users(:alex)
    assert user.authenticate("password")
  end

  test "authenticate with wrong password" do
    user = users(:alex)
    assert_not user.authenticate("wrong")
  end

  test "email-only user valid without wallet" do
    user = User.new(email: "test@example.com", password: "password")
    assert user.valid?, user.errors.full_messages.join(", ")
  end

  test "user invalid with no auth methods" do
    user = User.new(password: "password")
    assert_not user.valid?
    assert user.errors[:base].any? { |e| e.include?("Must have") }
  end

  test "has_password? returns true for password users" do
    assert users(:alex).has_password?
  end

  test "has_email? returns true for email users" do
    assert users(:alex).has_email?
  end

  # from_omniauth tests

  def google_auth(email: "newgoogle@example.com", name: "Google User", uid: "123456")
    OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, name: name }
    )
  end

  test "from_omniauth creates new user when no match" do
    auth = google_auth

    assert_difference "User.count", 1 do
      user = User.from_omniauth(auth)
      assert_equal "newgoogle@example.com", user.email
      assert_equal "Google User", user.name
      assert_equal "google_oauth2", user.provider
      assert_equal "123456", user.uid
      assert_equal 0, user.balance_cents
    end
  end

  test "from_omniauth links existing password user by email" do
    alex = users(:alex)
    auth = google_auth(email: alex.email, uid: "99999")

    assert_no_difference "User.count" do
      user = User.from_omniauth(auth)
      assert_equal alex.id, user.id
      assert_equal "google_oauth2", user.provider
      assert_equal "99999", user.uid
    end
  end

  test "from_omniauth returns existing OAuth user" do
    auth = google_auth(email: "oauth@example.com", uid: "55555")
    original = User.from_omniauth(auth)

    assert_no_difference "User.count" do
      returning = User.from_omniauth(auth)
      assert_equal original.id, returning.id
    end
  end

  test "slug is set on save" do
    user = users(:alex)
    user.save!
    assert user.slug.present?
  end
end
