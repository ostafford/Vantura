require "test_helper"

class TransactionMerchantServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @account = @user.accounts.create!(
      up_account_id: "test_merchant_account",
      display_name: "Test Merchant Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
    @start_date = Date.new(2025, 11, 1)
    @end_date = Date.new(2025, 11, 30)
  end

  test "should return array of merchant data for expenses" do
    @account.transactions.create!(
      description: "Grocery Store",
      amount: -100.0,
      transaction_date: @start_date + 5.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Grocery Store"
    )
    @account.transactions.create!(
      description: "Grocery Store",
      amount: -50.0,
      transaction_date: @start_date + 10.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Grocery Store"
    )
    @account.transactions.create!(
      description: "Gas Station",
      amount: -75.0,
      transaction_date: @start_date + 15.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Gas Station"
    )

    merchants = TransactionMerchantService.call(@account, "expense", @start_date, @end_date, limit: 3)

    assert_instance_of Array, merchants
    assert merchants.any?
    assert_includes merchants.map { |m| m[:merchant] }, "Grocery Store"
    assert_includes merchants.map { |m| m[:merchant] }, "Gas Station"
  end

  test "should return array of merchant data for income" do
    @account.transactions.create!(
      description: "Salary",
      amount: 3000.0,
      transaction_date: @start_date + 1.day,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Employer"
    )
    @account.transactions.create!(
      description: "Bonus",
      amount: 500.0,
      transaction_date: @start_date + 5.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Employer"
    )

    merchants = TransactionMerchantService.call(@account, "income", @start_date, @end_date, limit: 3)

    assert_instance_of Array, merchants
    assert merchants.any?
    assert_includes merchants.map { |m| m[:merchant] }, "Employer"
  end

  test "should calculate totals correctly" do
    @account.transactions.create!(
      description: "Store",
      amount: -100.0,
      transaction_date: @start_date + 5.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store"
    )
    @account.transactions.create!(
      description: "Store",
      amount: -50.0,
      transaction_date: @start_date + 10.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store"
    )

    merchants = TransactionMerchantService.call(@account, "expense", @start_date, @end_date, limit: 3)

    store_merchant = merchants.find { |m| m[:merchant] == "Store" }
    assert_not_nil store_merchant
    assert_equal 150.0, store_merchant[:total]
    assert_equal 2, store_merchant[:count]
  end

  test "should detect hypothetical transactions" do
    @account.transactions.create!(
      description: "Store",
      amount: -100.0,
      transaction_date: @start_date + 5.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Store"
    )
    @account.transactions.create!(
      description: "Store",
      amount: -50.0,
      transaction_date: @start_date + 10.days,
      status: "HYPOTHETICAL",
      is_hypothetical: true,
      merchant: "Store"
    )

    merchants = TransactionMerchantService.call(@account, "expense", @start_date, @end_date, limit: 3)

    store_merchant = merchants.find { |m| m[:merchant] == "Store" }
    assert_not_nil store_merchant
    assert_equal true, store_merchant[:hypothetical]
  end

  test "should respect limit parameter" do
    5.times do |i|
      @account.transactions.create!(
        description: "Store #{i}",
        amount: -100.0,
        transaction_date: @start_date + i.days,
        status: "SETTLED",
        is_hypothetical: false,
        merchant: "Store #{i}"
      )
    end

    merchants = TransactionMerchantService.call(@account, "expense", @start_date, @end_date, limit: 3)

    assert merchants.length <= 3
  end

  test "should return empty array when no transactions" do
    merchants = TransactionMerchantService.call(@account, "expense", @start_date, @end_date, limit: 3)

    assert_equal [], merchants
  end

  test "should only include transactions within date range" do
    @account.transactions.create!(
      description: "In Range",
      amount: -100.0,
      transaction_date: @start_date + 5.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "In Range"
    )
    @account.transactions.create!(
      description: "Out of Range",
      amount: -50.0,
      transaction_date: @start_date - 5.days,
      status: "SETTLED",
      is_hypothetical: false,
      merchant: "Out of Range"
    )

    merchants = TransactionMerchantService.call(@account, "expense", @start_date, @end_date, limit: 3)

    assert_includes merchants.map { |m| m[:merchant] }, "In Range"
    assert_not_includes merchants.map { |m| m[:merchant] }, "Out of Range"
  end
end
