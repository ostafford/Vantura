require "test_helper"

class Api::V1::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(:one)
    @account = accounts(:one)
  end

  test "GET /api/v1/transactions returns data and pagination meta" do
    get "/api/v1/transactions", params: { filter: "all" }

    assert_response :success

    body = JSON.parse(@response.body)
    assert body["data"].is_a?(Hash), "data should be a hash"
    assert body["data"]["transactions"].is_a?(Array), "transactions should be an array"
    assert body["data"]["stats"].is_a?(Hash), "stats should be a hash"

    assert body["meta"].is_a?(Hash), "meta should be present"
    assert body["meta"]["pagination"].is_a?(Hash), "pagination meta should be present"
    %w[page per_page total total_pages].each do |k|
      assert body["meta"]["pagination"].key?(k), "pagination should include #{k}"
    end
  end

  test "GET /api/v1/transactions/:year/:month returns month data" do
    today = Date.today
    get "/api/v1/transactions/#{today.year}/#{today.month}", params: { filter: "all" }

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["data"].is_a?(Hash)
    assert body["data"]["transactions"].is_a?(Array)
    assert body["data"]["stats"].is_a?(Hash)
  end

  test "GET /api/v1/transactions/search returns results and stats when query length >= 3" do
    get "/api/v1/transactions/search", params: { q: "Gro", year: Date.today.year, month: Date.today.month }

    assert_response :success
    body = JSON.parse(@response.body)
    assert body["data"].is_a?(Hash)
    assert body["data"]["transactions"].is_a?(Array)
    assert body["data"]["stats"].is_a?(Hash)
  end
end


