require "test_helper"

class PropTest < ActiveSupport::TestCase
  test "slug is set on save" do
    prop = props(:one)
    prop.save!
    assert_equal "argentina-total-goals-1.5", prop.slug
  end
end
