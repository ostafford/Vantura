require "test_helper"

class TransactionsSearchServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "ILIKE search with query length >= 3 limits and orders results" do
    service = Transactions::SearchService.new(account: @account, query: "Gro", year: Date.today.year, month: Date.today.month)
    result = service.call

    assert result.transactions.is_a?(Array)
    assert result.stats.is_a?(Hash)
    # Ensure limited result set and ordered by date desc
    dates = result.transactions.map(&:transaction_date)
    assert_equal dates.sort.reverse, dates
    assert result.transactions.length <= 10
  end

  test "fallback to month stats when query too short" do
    service = Transactions::SearchService.new(account: @account, query: "Up", year: Date.today.year, month: Date.today.month)
    result = service.call

    assert result.transactions.respond_to?(:each)
    assert result.stats.is_a?(Hash)
    assert result.stats.key?(:expense_total)
    assert result.stats.key?(:income_total)
  end
end


