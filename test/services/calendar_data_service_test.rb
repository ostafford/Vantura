require "test_helper"

class CalendarDataServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @account = @user.accounts.create!(
      up_account_id: "test_calendar_data_account",
      display_name: "Test Calendar Data Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
    @date = Date.new(2025, 11, 15)
  end

  test "returns expected structure for month view" do
    data = CalendarDataService.call(@account, { year: 2025, month: 11 }, "month")

    assert_instance_of Hash, data
    assert_includes data, :date
    assert_includes data, :year
    assert_includes data, :month
    assert_includes data, :view
    assert_includes data, :start_date
    assert_includes data, :end_date
    assert_includes data, :transactions
    assert_includes data, :transactions_by_date
    assert_includes data, :weeks
    assert_includes data, :eow_amounts
    assert_includes data, :end_of_month_balance
    assert_includes data, :calendar_stats
    assert_nil data[:week_days]
    assert_nil data[:week_end_balance]
  end

  test "returns expected structure for week view" do
    data = CalendarDataService.call(@account, { year: 2025, month: 11, day: 15 }, "week")

    assert_instance_of Hash, data
    assert_includes data, :week_days
    assert_includes data, :week_end_balance
    assert_nil data[:weeks]
    assert_nil data[:eow_amounts]
  end

  test "parses date from params" do
    data = CalendarDataService.call(@account, { year: 2025, month: 10 }, "month")

    assert_equal Date.new(2025, 10, 1), data[:date]
    assert_equal 2025, data[:year]
    assert_equal 10, data[:month]
  end

  test "uses today as default date" do
    data = CalendarDataService.call(@account, {}, "month")

    assert_equal Date.today, data[:date]
  end

  test "calculates start_date and end_date for month view" do
    data = CalendarDataService.call(@account, { year: 2025, month: 11 }, "month")

    assert_equal Date.new(2025, 11, 1), data[:start_date]
    assert_equal Date.new(2025, 11, 30), data[:end_date]
  end

  test "calculates start_date and end_date for week view" do
    week_date = Date.new(2025, 11, 15)
    data = CalendarDataService.call(@account, { year: 2025, month: 11, day: 15 }, "week")

    assert_equal week_date.beginning_of_week(:monday), data[:start_date]
    assert_equal week_date.end_of_week(:monday), data[:end_date]
  end

  test "includes transactions in date range" do
    @account.transactions.create!(
      description: "In Range",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Out of Range",
      amount: -200.0,
      transaction_date: @date.prev_month,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = CalendarDataService.call(@account, { year: 2025, month: 11 }, "month")

    assert_equal 1, data[:transactions].count
  end

  test "groups transactions by date" do
    @account.transactions.create!(
      description: "Transaction 1",
      amount: -100.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )
    @account.transactions.create!(
      description: "Transaction 2",
      amount: -200.0,
      transaction_date: @date,
      status: "SETTLED",
      is_hypothetical: false
    )

    data = CalendarDataService.call(@account, { year: 2025, month: 11 }, "month")

    assert_equal 1, data[:transactions_by_date].keys.count
    assert_equal 2, data[:transactions_by_date][@date].count
  end

  test "builds calendar weeks for month view" do
    data = CalendarDataService.call(@account, { year: 2025, month: 11 }, "month")

    assert_instance_of Array, data[:weeks]
    assert data[:weeks].all? { |week| week.is_a?(Array) && week.length == 7 }
  end

  test "builds week days for week view" do
    data = CalendarDataService.call(@account, { year: 2025, month: 11, day: 15 }, "week")

    assert_instance_of Array, data[:week_days]
    assert_equal 7, data[:week_days].length
    assert data[:week_days].first[:date].is_a?(Date)
  end

  test "calculates end of month balance" do
    @account.update!(current_balance: 1000.0)

    data = CalendarDataService.call(@account, { year: 2025, month: 11 }, "month")

    assert data[:end_of_month_balance].is_a?(Numeric)
  end

  test "includes calendar stats" do
    data = CalendarDataService.call(@account, { year: 2025, month: 11 }, "month")

    assert_instance_of Hash, data[:calendar_stats]
    assert_includes data[:calendar_stats], :actual_income
    assert_includes data[:calendar_stats], :actual_expenses
  end

  test "handles invalid date params" do
    data = CalendarDataService.call(@account, { year: 2025, month: 13 }, "month")

    assert_equal Date.today, data[:date]
  end
end
