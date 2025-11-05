require "test_helper"

class TransactionQueryHelpersTest < ActiveSupport::TestCase
  def setup
    @account = accounts(:one)
    @start_date = Date.today.beginning_of_month
    @end_date = Date.today.end_of_month
  end

  test "TransactionMerchantService returns merchants for expenses" do
    # Create test transactions with merchant names
    transaction1 = @account.transactions.create!(
      description: "Test Expense 1",
      amount: -100.00,
      merchant: "Shop A",
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    transaction2 = @account.transactions.create!(
      description: "Test Expense 2",
      amount: -50.00,
      merchant: "Shop B",
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    result = TransactionMerchantService.call(
      @account,
      "expense",
      @start_date,
      @end_date,
      limit: 3
    )

    assert result.is_a?(Array)
    assert result.length > 0, "Result should not be empty"

    # Check that we got merchant data structure
    merchant = result.first
    assert merchant.key?(:merchant)
    assert merchant.key?(:total)
    assert merchant.key?(:count)
    assert merchant.key?(:hypothetical)
  end

  test "TransactionMerchantService returns merchants for income" do
    # Create test transactions
    @account.transactions.create!(
      description: "Salary",
      amount: 1000.00,
      merchant: "Employer Inc",
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    result = TransactionMerchantService.call(
      @account,
      "income",
      @start_date,
      @end_date,
      limit: 3
    )

    assert result.is_a?(Array)
    assert result.any? { |m| m[:merchant] == "Employer Inc" }
  end

  test "TransactionMerchantService includes hypothetical flag" do
    # Create real and hypothetical transactions
    @account.transactions.create!(
      description: "Real Transaction",
      amount: -50.00,
      merchant: "Shop Test",
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Hypothetical Transaction",
      amount: -30.00,
      merchant: "Shop Test",
      transaction_date: Date.today,
      status: "HYPOTHETICAL",
      is_hypothetical: true
    )

    result = TransactionMerchantService.call(
      @account,
      "expense",
      @start_date,
      @end_date,
      limit: 5
    )

    assert result.length > 0
    # Find our test merchant
    merchant = result.find { |m| m[:merchant] == "Shop Test" }
    assert_not_nil merchant, "Should find Shop Test merchant"
    assert merchant.key?(:hypothetical), "Should have hypothetical key"
    assert merchant[:hypothetical], "Should detect hypothetical transactions"
  end

  test "TransactionMerchantService respects limit parameter" do
    # Create 5 test transactions
    5.times do |i|
      @account.transactions.create!(
        description: "Test Expense #{i}",
        amount: -50.00 * (i + 1),
        merchant: "Shop #{i}",
        transaction_date: Date.today,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    result = TransactionMerchantService.call(
      @account,
      "expense",
      @start_date,
      @end_date,
      limit: 3
    )

    assert_operator result.count, :<=, 3
  end
end
