require "test_helper"

module RecurringTransactions
  class BreakdownServiceTest < ActiveSupport::TestCase
    def setup
      @account = accounts(:one)
    end

    test "returns breakdown hash with all required keys" do
      result = BreakdownService.call(@account)

      assert_instance_of Hash, result
      assert_includes result, :week_income
      assert_includes result, :week_expenses
      assert_includes result, :month_income
      assert_includes result, :month_expenses
      assert_includes result, :next_occurrence_date
      assert_includes result, :next_occurrence_amount
      assert_includes result, :next_occurrence_desc
    end

    test "calculates weekly breakdown correctly" do
      # Create recurring transactions due this week
      week_start = Date.today.beginning_of_week(:monday)
      week_end = Date.today.end_of_week(:monday)

      @account.recurring_transactions.create!(
        description: "Weekly Income",
        amount: 100.0,
        frequency: "weekly",
        next_occurrence_date: week_start + 2.days,
        is_active: true,
        transaction_type: "income",
        date_tolerance_days: 3
      )

      @account.recurring_transactions.create!(
        description: "Weekly Expense",
        amount: -50.0,
        frequency: "weekly",
        next_occurrence_date: week_start + 3.days,
        is_active: true,
        transaction_type: "expense",
        date_tolerance_days: 3
      )

      result = BreakdownService.call(@account)

      assert_equal 100.0, result[:week_income]
      assert_equal 50.0, result[:week_expenses]
    end

    test "calculates monthly breakdown correctly" do
      month_start = Date.today.beginning_of_month
      month_end = Date.today.end_of_month

      # Clear existing to get clean test
      @account.recurring_transactions.destroy_all

      @account.recurring_transactions.create!(
        description: "Monthly Income",
        amount: 2000.0,
        frequency: "monthly",
        next_occurrence_date: month_start + 10.days,
        is_active: true,
        transaction_type: "income",
        date_tolerance_days: 3
      )

      @account.recurring_transactions.create!(
        description: "Monthly Rent",
        amount: -1500.0,
        frequency: "monthly",
        next_occurrence_date: month_start + 5.days,
        is_active: true,
        transaction_type: "expense",
        date_tolerance_days: 3
      )

      result = BreakdownService.call(@account)

      assert_equal 2000.0, result[:month_income]
      assert_equal 1500.0, result[:month_expenses]
    end

    test "finds next occurrence correctly" do
      today = Date.today
      
      # Clear existing to get clean test
      @account.recurring_transactions.destroy_all

      @account.recurring_transactions.create!(
        description: "First Occurrence",
        amount: -100.0,
        frequency: "monthly",
        next_occurrence_date: today + 5.days,
        is_active: true,
        transaction_type: "expense",
        date_tolerance_days: 3
      )

      @account.recurring_transactions.create!(
        description: "Later Occurrence",
        amount: -200.0,
        frequency: "monthly",
        next_occurrence_date: today + 10.days,
        is_active: true,
        transaction_type: "expense",
        date_tolerance_days: 3
      )

      result = BreakdownService.call(@account)

      assert_equal today + 5.days, result[:next_occurrence_date]
      assert_equal -100.0, result[:next_occurrence_amount]
      assert_equal "First Occurrence", result[:next_occurrence_desc]
    end

    test "returns nil for next occurrence when no active recurring transactions" do
      # Clear existing and create only inactive recurring transaction
      @account.recurring_transactions.destroy_all
      
      @account.recurring_transactions.create!(
        description: "Inactive",
        amount: -100.0,
        frequency: "monthly",
        next_occurrence_date: Date.today + 5.days,
        is_active: false,
        transaction_type: "expense",
        date_tolerance_days: 3
      )

      result = BreakdownService.call(@account)

      assert_nil result[:next_occurrence_date]
      assert_nil result[:next_occurrence_amount]
      assert_nil result[:next_occurrence_desc]
    end

    test "handles empty account with no recurring transactions" do
      # Use a fresh account
      new_account = accounts(:one)
      new_account.recurring_transactions.destroy_all

      result = BreakdownService.call(new_account)

      assert_equal 0.0, result[:week_income]
      assert_equal 0.0, result[:week_expenses]
      assert_equal 0.0, result[:month_income]
      assert_equal 0.0, result[:month_expenses]
      assert_nil result[:next_occurrence_date]
    end

    test "only includes active recurring transactions" do
      week_start = Date.today.beginning_of_week(:monday)
      week_end = Date.today.end_of_week(:monday)

      @account.recurring_transactions.create!(
        description: "Active Income",
        amount: 100.0,
        frequency: "weekly",
        next_occurrence_date: week_start + 2.days,
        is_active: true,
        transaction_type: "income",
        date_tolerance_days: 3
      )

      @account.recurring_transactions.create!(
        description: "Inactive Income",
        amount: 200.0,
        frequency: "weekly",
        next_occurrence_date: week_start + 2.days,
        is_active: false,
        transaction_type: "income",
        date_tolerance_days: 3
      )

      result = BreakdownService.call(@account)

      assert_equal 100.0, result[:week_income]
      assert_not_equal 300.0, result[:week_income]
    end
  end
end

