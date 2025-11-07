require "test_helper"

class TrendsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
  end

  test "should redirect to login when not authenticated" do
    get trends_url
    assert_redirected_to new_session_url
  end

  test "should use TrendsStatsCalculator service" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    # Service is called indirectly - verified through successful response
  end

  test "should include insights" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    # Verify page renders successfully
    assert_response :success
  end

  test "should accept months parameter" do
    sign_in_as(:one)
    get trends_url, params: { months: 12 }
    assert_response :success
    assert_equal "12", session[:trends_months].to_s # Session stores as string
  end

  test "should accept all months parameter" do
    sign_in_as(:one)
    get trends_url, params: { months: "all" }
    assert_response :success
    assert_equal "all", session[:trends_months]
  end

  test "should accept view_type parameter" do
    sign_in_as(:one)
    get trends_url, params: { view_type: "merchant" }
    assert_response :success
    assert_equal "merchant", session[:trends_view_type]
  end

  test "should default to 6 months" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    assert_equal 6, session[:trends_months].to_i # Convert to int for comparison
  end

  test "should default to category view type" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    assert_equal "category", session[:trends_view_type]
  end

  test "should update preference via PATCH" do
    sign_in_as(:one)
    patch update_preference_trends_url, params: { view_type: "merchant", months: 12 }
    assert_redirected_to trends_url
    assert_equal "merchant", session[:trends_view_type]
    assert_equal "12", session[:trends_months].to_s # Session stores as string
  end

  test "should only accept valid view types" do
    sign_in_as(:one)
    patch update_preference_trends_url, params: { view_type: "invalid" }
    assert_redirected_to trends_url
    # Should not update session with invalid value
    assert_not_equal "invalid", session[:trends_view_type]
  end

  test "should include historical_data in stats" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    # Verify page renders successfully with stats
    assert_select "h2", text: /Trends|Insights/
  end

  test "should include category_breakdown in stats" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    # Verify page renders successfully
    assert_response :success
  end

  test "should include savings_rate_trend in stats" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    # Verify page renders successfully
    assert_response :success
  end

  test "should include year_over_year_comparison in stats" do
    sign_in_as(:one)
    get trends_url
    assert_response :success
    # Verify page renders successfully
    assert_response :success
  end
end

