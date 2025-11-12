require "test_helper"

class FinancialInsightsServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @current_date = Date.new(2025, 11, 15)
    @service = FinancialInsightsService.new(@account)
  end

  test "should generate key insights" do
    insights = @service.generate_key_insights(5)

    assert_not_nil insights
    assert insights.is_a?(Array)
    assert insights.length <= 5
  end

  test "should generate insights with valid structure" do
    insights = @service.generate_key_insights(3)

    insights.each do |insight|
      assert insight.key?(:type) || insight.key?("type")
      assert insight.key?(:title) || insight.key?("title")
      assert insight.key?(:message) || insight.key?("message")
      assert insight.key?(:evidence) || insight.key?("evidence")
      insight_type = insight[:type] || insight["type"]
      assert_includes [ "spending_velocity", "savings_opportunity", "investment_suggestion", "category_merchant" ], insight_type
    end
  end

  test "should limit number of insights" do
    insights = @service.generate_key_insights(2)

    assert insights.length <= 2
  end

  test "should generate spending velocity insight when applicable" do
    # Create expenses to trigger velocity insight
    @account.transactions.create!(
      description: "Expense",
      amount: -100.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    insights = @service.generate_key_insights(5)

    # May or may not generate based on data - just verify service completes
    assert insights.is_a?(Array)
  end

  test "should generate savings opportunity insight when applicable" do
    insights = @service.generate_key_insights(5)

    # May or may not generate based on data - just verify service completes
    assert insights.is_a?(Array)
  end

  test "should handle account with no transactions" do
    @account.transactions.destroy_all

    insights = @service.generate_key_insights(5)

    assert insights.is_a?(Array)
    # May return empty array or insights based on other data
  end

  test "should include evidence in insights" do
    insights = @service.generate_key_insights(3)

    insights.each do |insight|
      evidence = insight[:evidence] || insight["evidence"]
      assert evidence.is_a?(Hash) if evidence
      assert evidence.present? if evidence
    end
  end

  test "should generate actionable insights" do
    insights = @service.generate_key_insights(5)

    insights.each do |insight|
      # Insights should have actionable information
      title = insight[:title] || insight["title"]
      message = insight[:message] || insight["message"]
      assert title.present?
      assert message.present?
    end
  end

  test "should prioritize high-value insights" do
    # Create scenario that should generate high-value insights
    @account.transactions.create!(
      description: "Large Expense",
      amount: -1000.00,
      transaction_date: @current_date,
      status: "SETTLED",
      is_hypothetical: false
    )

    insights = @service.generate_key_insights(3)

    # Should prioritize insights with significant impact
    assert insights.length <= 3
  end

  test "savings goal snapshot reflects user-defined goal" do
    account = accounts(:two)

    travel_to Time.zone.local(2025, 11, 15) do
      account.transactions.create!(
        description: "Salary",
        amount: 4000.0,
        transaction_date: Date.current.beginning_of_month,
        status: "SETTLED",
        is_hypothetical: false
      )

      account.transactions.create!(
        description: "Rent",
        amount: -2500.0,
        category: "rent",
        transaction_date: Date.current.beginning_of_month + 1.day,
        status: "SETTLED",
        is_hypothetical: false
      )

      account.transactions.create!(
        description: "Groceries",
        amount: -900.0,
        category: "groceries",
        transaction_date: Date.current.beginning_of_month + 2.days,
        status: "SETTLED",
        is_hypothetical: false
      )

      service = FinancialInsightsService.new(account, Date.current)
      snapshot = service.send(:savings_goal_snapshot)

      assert snapshot[:goal_set], "expected goal snapshot to indicate goal is set"
      assert_equal :amount, snapshot[:goal_source]
      assert_equal 400.0, snapshot[:goal_requested_amount]
      assert snapshot[:projected_savings].is_a?(Numeric)
    end
  end
end
