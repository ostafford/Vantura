require "test_helper"

class BudgetCoachServiceTest < ActiveSupport::TestCase
  test "generate_budget_plan honors user savings goal" do
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
        description: "Dining Out",
        amount: -900.0,
        category: "dining",
        transaction_date: Date.current.beginning_of_month + 2.days,
        status: "SETTLED",
        is_hypothetical: false
      )

      account.transactions.create!(
        description: "Shopping",
        amount: -800.0,
        category: "shopping",
        transaction_date: Date.current.beginning_of_month + 3.days,
        status: "SETTLED",
        is_hypothetical: false
      )

      plan = BudgetCoachService.new(account, Date.current).generate_budget_plan

      assert plan, "Expected budget plan to be generated"
      assert plan[:goal_context][:has_user_goal]
      assert_equal :amount, plan[:goal_context][:source]
      assert_in_delta 400.0, plan[:goal_context][:requested_amount], 0.01
      assert_in_delta 400.0, plan[:savings_goal], 0.01
    end
  end
end
