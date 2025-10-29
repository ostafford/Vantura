require "test_helper"

class FilterTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @filter = Filter.new(
      name: "Test Filter",
      user: @user,
      filter_types: [ "category" ],
      filter_params: { "categories" => [ "Food", "Transport" ] }
    )
  end

  # Validations

  test "should be valid with valid attributes" do
    assert @filter.valid?
  end

  test "should require name" do
    @filter.name = nil
    assert_not @filter.valid?
    assert_includes @filter.errors[:name], "can't be blank"
  end

  test "should require filter_types" do
    @filter.filter_types = nil
    assert_not @filter.valid?
    assert_includes @filter.errors[:filter_types], "can't be blank"
  end

  test "should enforce uniqueness of name scoped to user" do
    @filter.save!
    duplicate_filter = Filter.new(
      name: "Test Filter",
      user: @user,
      filter_types: [ "merchant" ]
    )
    assert_not duplicate_filter.valid?
    assert_includes duplicate_filter.errors[:name], "has already been taken"
  end

  test "should allow same name for different users" do
    @filter.save!
    other_user = users(:two)
    duplicate_filter = Filter.new(
      name: "Test Filter",
      user: other_user,
      filter_types: [ "merchant" ]
    )
    assert duplicate_filter.valid?
  end

  # Callbacks

  test "should set default filter_params before validation" do
    filter = Filter.new(name: "Test", user: @user, filter_types: [ "category" ])
    filter.valid?
    assert_equal({}, filter.filter_params)
  end

  test "should set default filter_types before validation" do
    filter = Filter.new(name: "Test", user: @user)
    filter.valid?
    assert_equal([], filter.filter_types)
  end

  test "should normalize filter_types to remove duplicates" do
    filter = Filter.new(
      name: "Test",
      user: @user,
      filter_types: [ "category", "merchant", "category" ]
    )
    filter.valid?
    assert_equal([ "category", "merchant" ], filter.filter_types)
  end

  # Validations

  test "should validate filter_types is an array" do
    @filter.filter_types = "invalid"
    assert_not @filter.valid?
    assert_includes @filter.errors[:filter_types], "must be an array of valid filter types"
  end

  test "should validate filter_types contains valid types" do
    @filter.filter_types = [ "invalid_type" ]
    assert_not @filter.valid?
    assert_includes @filter.errors[:filter_types], "must be an array of valid filter types"
  end

  test "should accept valid filter types" do
    valid_types = [ "category", "merchant", "status", "recurring_transactions" ]
    @filter.filter_types = valid_types
    assert @filter.valid?
  end

  test "should validate filter_params is a hash" do
    @filter.filter_params = "invalid"
    @filter.valid?
    # The callback should convert it to a hash
    assert @filter.filter_params.is_a?(Hash)
  end

  # Associations

  test "should belong to user" do
    assert_respond_to @filter, :user
  end

  test "should destroy filter when user is destroyed" do
    @filter.save!
    user_filter_count = @user.filters.count
    assert_difference("Filter.count", -user_filter_count) do
      @user.destroy
    end
  end

  # Scopes

  test "recent scope should order by created_at descending" do
    filter1 = Filter.create!(name: "First", user: @user, filter_types: [ "category" ])
    filter2 = Filter.create!(name: "Second", user: @user, filter_types: [ "merchant" ])

    recent_filters = Filter.recent.to_a
    # Check that the most recent filter is first
    assert_equal filter2.id, recent_filters.first.id
  end

  # Helper methods

  test "display_name should humanize the name" do
    @filter.name = "test_filter_name"
    assert_equal "Test filter name", @filter.display_name
  end

  test "filter_description should describe category filter" do
    @filter.filter_types = [ "category" ]
    @filter.filter_params = { "categories" => [ "Food", "Transport" ] }
    description = @filter.filter_description
    assert_includes description, "Categories: Food, Transport"
  end

  test "filter_description should describe merchant filter" do
    @filter.filter_types = [ "merchant" ]
    @filter.filter_params = { "merchants" => [ "Woolworths", "Coles" ] }
    description = @filter.filter_description
    assert_includes description, "Merchants: Woolworths, Coles"
  end

  test "filter_description should describe status filter" do
    @filter.filter_types = [ "status" ]
    @filter.filter_params = { "statuses" => [ "SETTLED", "HELD" ] }
    description = @filter.filter_description
    assert_includes description, "Status: SETTLED, HELD"
  end

  test "filter_description should describe recurring filter" do
    @filter.filter_types = [ "recurring_transactions" ]
    @filter.filter_params = { "recurring_transactions" => "true" }
    description = @filter.filter_description
    assert_includes description, "From Recurring Only"
  end

  test "filter_description should show 'All' when no parameters" do
    @filter.filter_types = [ "category" ]
    @filter.filter_params = {}
    description = @filter.filter_description
    assert_includes description, "Categories: All"
  end

  test "filter_description should handle multiple filter types" do
    @filter.filter_types = [ "category", "merchant" ]
    @filter.filter_params = {
      "categories" => [ "Food" ],
      "merchants" => [ "Woolworths" ]
    }
    description = @filter.filter_description
    assert_includes description, "Categories: Food"
    assert_includes description, "Merchants: Woolworths"
  end

  # Edge cases

  test "should handle empty filter_params gracefully" do
    @filter.filter_params = {}
    assert @filter.valid?
  end

  test "should handle nil filter_params" do
    @filter.filter_params = nil
    @filter.valid?
    assert_equal({}, @filter.filter_params)
  end

  test "should handle empty filter_types array" do
    @filter.filter_types = []
    assert_not @filter.valid?
  end

  test "should handle filter_types with nil values" do
    @filter.filter_types = [ "category", nil, "merchant" ]
    @filter.valid?
    assert_equal([ "category", "merchant" ], @filter.filter_types)
  end

  # JSONB round-trip persistence

  test "jsonb columns persist and cast to correct Ruby types" do
    params_hash = { "categories" => [ "Food", "Transport" ], "flags" => { "important" => true } }
    types_array = [ "category", "status" ]

    filter = Filter.create!(
      name: "JSONB Round Trip",
      user: @user,
      filter_types: types_array,
      filter_params: params_hash,
      date_range: { "from" => "2025-01-01", "to" => "2025-01-31" }
    )

    reloaded = Filter.find(filter.id)
    assert_kind_of Hash, reloaded.filter_params
    assert_kind_of Array, reloaded.filter_types
    assert_kind_of Hash, reloaded.date_range

    assert_equal params_hash, reloaded.filter_params
    assert_equal types_array, reloaded.filter_types
    assert_equal({ "from" => "2025-01-01", "to" => "2025-01-31" }, reloaded.date_range)
  end
end
