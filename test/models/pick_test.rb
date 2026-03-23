require "test_helper"

class PickTest < ActiveSupport::TestCase
  test "slug is set on save" do
    pick = picks(:one)
    pick.save!
    assert_equal "argentina-total-goals-more", pick.slug
  end
end
