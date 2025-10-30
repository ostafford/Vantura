require "test_helper"

class Api::V1::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(:one)
  end

  test "GET /api/v1/dashboard/stats returns data envelope" do
    get "/api/v1/dashboard/stats"

    assert_response :success

    body = JSON.parse(@response.body)
    assert body["data"].is_a?(Hash), "data should be a hash"
    assert body["meta"].is_a?(Hash), "meta should be present"
    assert body["meta"]["timestamp"].present?, "meta should include timestamp"
  end
end


