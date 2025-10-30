require "test_helper"

class TransactionsCreateServiceTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
  end

  test "creates hypothetical expense with negative amount" do
    service = Transactions::CreateService.new(
      account: @account,
      params: { description: "Coffee", amount: 5.0, category: "Food", transaction_date: Date.today },
      transaction_type: "expense"
    )

    result = service.call

    assert result.success?
    tx = result.transaction
    assert_equal @account.id, tx.account_id
    assert tx.is_hypothetical?
    assert_equal "hypothetical", tx.status
    assert tx.amount.negative?, "expense should be negative"
  end

  test "creates income with positive amount by default" do
    service = Transactions::CreateService.new(
      account: @account,
      params: { description: "Salary", amount: 1000.0, category: "Income", transaction_date: Date.today, transaction_type: "income" }
    )

    result = service.call

    assert result.success?
    assert result.transaction.amount.positive?
  end
end


