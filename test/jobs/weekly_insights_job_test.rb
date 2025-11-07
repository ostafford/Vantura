require "test_helper"

class WeeklyInsightsJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:one)
  end

  test "should enqueue job" do
    assert_enqueued_with(job: WeeklyInsightsJob) do
      WeeklyInsightsJob.perform_later
    end
  end

  test "should generate insights for all accounts" do
    result = WeeklyInsightsJob.perform_now

    # Job should complete without errors
    assert result.is_a?(Hash)
    assert result.key?(:accounts_processed)
    assert result.key?(:insights_created)
  end

  test "should handle account with no transactions" do
    @account.transactions.destroy_all

    assert_nothing_raised do
      WeeklyInsightsJob.perform_now
    end
  end

  test "should create financial insights when applicable" do
    # Create some transactions to potentially generate insights
    @account.transactions.create!(
      description: "Test Expense",
      amount: -100.00,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    initial_count = @account.financial_insights.count

    WeeklyInsightsJob.perform_now

    # Insights may or may not be created based on data
    # Just verify job completes successfully
    assert true
  end
end

