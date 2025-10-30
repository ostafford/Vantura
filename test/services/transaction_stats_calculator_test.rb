require "test_helper"

class TransactionStatsCalculatorTest < ActiveSupport::TestCase
  def setup
    @account = accounts(:one)
    # Create some test transactions
    @account.transactions.create!(
      description: "Test Expense",
      amount: -100.00,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Test Income",
      amount: 500.00,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )
  end

  test "should calculate expense total correctly" do
    stats = TransactionStatsCalculator.call(@account, Date.today.beginning_of_month, Date.today.end_of_month)

    # Should return a non-negative number
    assert_operator stats[:expense_total], :>=, 0
    assert stats[:expense_total].is_a?(Numeric)
  end

  test "should calculate income total correctly" do
    stats = TransactionStatsCalculator.call(@account, Date.today.beginning_of_month, Date.today.end_of_month)

    # Should return a non-negative number
    assert_operator stats[:income_total], :>=, 0
    assert stats[:income_total].is_a?(Numeric)
  end

  test "should calculate net cash flow correctly" do
    stats = TransactionStatsCalculator.call(@account, Date.today.beginning_of_month, Date.today.end_of_month)

    # Net should equal income minus expense
    assert stats[:net_cash_flow].is_a?(Numeric)
    assert_equal stats[:net_cash_flow], stats[:income_total] - stats[:expense_total]
  end

  test "should return transaction count" do
    stats = TransactionStatsCalculator.call(@account, Date.today.beginning_of_month, Date.today.end_of_month)

    assert_operator stats[:transaction_count], :>=, 2
  end

  test "should return all expected keys" do
    stats = TransactionStatsCalculator.call(@account, Date.today.beginning_of_month, Date.today.end_of_month)

    expected_keys = [ :expense_total, :income_total, :expense_count, :income_count,
                     :net_cash_flow, :transaction_count, :top_category, :top_category_amount,
                     :top_expense_merchants, :top_income_merchants ]

    expected_keys.each do |key|
      assert stats.key?(key), "Expected key #{key} to be present"
    end
  end

  test "top merchants arrays have expected shape" do
    stats = TransactionStatsCalculator.call(@account, Date.today.beginning_of_month, Date.today.end_of_month)
    assert stats[:top_expense_merchants].is_a?(Array)
    assert stats[:top_income_merchants].is_a?(Array)

    if stats[:top_expense_merchants].any?
      m = stats[:top_expense_merchants].first
      assert m.key?(:merchant)
      assert m.key?(:total)
      assert m.key?(:count)
    end
  end
end
