require "test_helper"

class SlateTest < ActiveSupport::TestCase
  setup do
    @slate = slates(:one)
  end

  test "slug is set on save" do
    slate = Slate.create!(name: "My New Slate")
    assert_equal "my-new-slate", slate.slug
  end

  test "has many slate_matchups" do
    assert_equal 6, @slate.slate_matchups.count
  end

  test "has many contests" do
    assert_includes @slate.contests, contests(:one)
  end

  test "validates name presence" do
    slate = Slate.new(name: nil)
    assert_not slate.valid?
    assert_includes slate.errors[:name], "can't be blank"
  end
end
