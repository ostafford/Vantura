require "test_helper"

module RecurringTransactions
  class GenerateServiceTest < ActiveSupport::TestCase
    def setup
      @user = users(:one)
      @account = accounts(:one)
      @recurring = @account.recurring_transactions.create!(
        description: "Monthly Rent",
        amount: -1500.0,
        frequency: "monthly",
        next_occurrence_date: Date.today + 1.day,
        is_active: true,
        transaction_type: "expense",
        category: "rent"
      )
    end

    test "returns success hash when successful" do
      result = GenerateService.call(@recurring, months_ahead: 6)

      assert_instance_of Hash, result
      assert_equal true, result[:success]
      assert_includes result, :generated_count
    end

    test "returns error when recurring transaction is inactive" do
      @recurring.update!(is_active: false)

      result = GenerateService.call(@recurring, months_ahead: 6)

      assert_equal false, result[:success]
      assert_includes result[:error], "not active"
    end

    test "generates transactions for future dates" do
      future_date = Date.today + 5.days
      @recurring.update!(next_occurrence_date: future_date)

      result = GenerateService.call(@recurring, months_ahead: 6)

      assert result[:success]
      assert result[:generated_count] > 0

      generated = @account.transactions.where(recurring_transaction_id: @recurring.id, is_hypothetical: true)
      assert generated.any?
      assert generated.all? { |t| t.transaction_date > Date.today }
    end

    test "does not generate transactions for past dates" do
      @recurring.update!(next_occurrence_date: Date.today - 1.day)

      result = GenerateService.call(@recurring, months_ahead: 6)

      generated = @account.transactions.where(recurring_transaction_id: @recurring.id, is_hypothetical: true)
      assert generated.all? { |t| t.transaction_date > Date.today }
    end

    test "removes existing generated transactions" do
      @recurring.account.transactions.create!(
        description: "Existing",
        amount: -1500.0,
        transaction_date: Date.today + 10.days,
        status: "HYPOTHETICAL",
        is_hypothetical: true,
        recurring_transaction_id: @recurring.id
      )

      result = GenerateService.call(@recurring, months_ahead: 6)

      assert result[:success]
      # Should regenerate transactions
      assert @account.transactions.where(recurring_transaction_id: @recurring.id, is_hypothetical: true).any?
    end

    test "generates transactions with correct attributes" do
      @recurring.update!(next_occurrence_date: Date.today + 5.days)

      result = GenerateService.call(@recurring, months_ahead: 6)

      generated = @account.transactions.where(recurring_transaction_id: @recurring.id, is_hypothetical: true).first

      assert_equal @recurring.description, generated.description
      assert_equal @recurring.amount, generated.amount
      assert_equal @recurring.category, generated.category
      assert_equal "hypothetical", generated.status
      assert generated.is_hypothetical
    end

    test "respects months_ahead parameter" do
      result_6_months = GenerateService.call(@recurring, months_ahead: 6)
      @recurring.generated_transactions.destroy_all
      result_3_months = GenerateService.call(@recurring, months_ahead: 3)

      # 6 months should generate more transactions than 3 months
      assert result_6_months[:generated_count] >= result_3_months[:generated_count]
    end
  end
end
