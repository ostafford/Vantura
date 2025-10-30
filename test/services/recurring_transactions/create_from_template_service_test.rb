require "test_helper"

class RecurringTransactionsCreateFromTemplateServiceTest < ActiveSupport::TestCase
  setup do
    @template = transactions(:expense_one)
  end

  test "creates recurring from template and generates projections" do
    next_date = Date.today + 7.days
    result = RecurringTransactions::CreateFromTemplateService.new(
      transaction: @template,
      frequency: "weekly",
      next_occurrence_date: next_date,
      amount_tolerance: 0.1,
      projection_months: 3
    ).call

    assert result.success?
    recurring = result.recurring
    assert_equal @template.account_id, recurring.account_id
    assert_equal @template.description, recurring.description
    assert_equal "weekly", recurring.frequency
    assert_equal next_date, recurring.next_occurrence_date
    assert recurring.is_active
  end
end


