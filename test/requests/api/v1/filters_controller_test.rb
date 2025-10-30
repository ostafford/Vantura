require "test_helper"

class Api::V1::FiltersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(:one)
  end

  test "GET /api/v1/filters returns data envelope" do
    get "/api/v1/filters"

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["data"].is_a?(Array) || body["data"].is_a?(Hash), "data should be array or hash"
    assert body["meta"].is_a?(Hash), "meta should be present"
  end
end


