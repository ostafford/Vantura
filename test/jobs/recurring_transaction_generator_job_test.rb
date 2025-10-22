require "test_helper"

class RecurringTransactionGeneratorJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
    @account = @user.accounts.create!(
      up_account_id: "test_recurring_account",
      display_name: "Test Account",
      account_type: "TRANSACTIONAL",
      current_balance: 1000.0
    )
  end

  test "should enqueue job" do
    assert_enqueued_with(job: RecurringTransactionGeneratorJob) do
      RecurringTransactionGeneratorJob.perform_later
    end
  end

  test "should be queued on low_priority queue" do
    job = RecurringTransactionGeneratorJob.perform_later
    assert_equal "low_priority", job.queue_name
  end

  test "should accept months_ahead parameter" do
    assert_enqueued_with(job: RecurringTransactionGeneratorJob, args: [ { months_ahead: 6 } ]) do
      RecurringTransactionGeneratorJob.perform_later(months_ahead: 6)
    end
  end

  test "should process active patterns without errors" do
    # Create active recurring pattern
    recurring = @account.recurring_transactions.create!(
      description: "Monthly Rent",
      amount: -1500.0,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      transaction_type: "expense",
      is_active: true,
      projection_months: "3" # Limited to avoid creating too many in test
    )

    # Job should run without errors
    assert_nothing_raised do
      perform_enqueued_jobs do
        RecurringTransactionGeneratorJob.perform_now(months_ahead: 3)
      end
    end
  end

  test "should skip inactive patterns" do
    # Clear all recurring transactions to isolate test
    RecurringTransaction.destroy_all
    initial_transaction_count = Transaction.count

    # Create inactive recurring pattern
    inactive = @account.recurring_transactions.create!(
      description: "Cancelled Subscription",
      amount: -9.99,
      frequency: "monthly",
      next_occurrence_date: Date.today + 1.month,
      transaction_type: "expense",
      is_active: false,
      projection_months: "indefinite"
    )

    perform_enqueued_jobs do
      RecurringTransactionGeneratorJob.perform_now
    end

    # Should not generate any transactions for inactive pattern
    assert_equal initial_transaction_count, Transaction.count
  end

  test "should return summary hash" do
    result = perform_enqueued_jobs do
      RecurringTransactionGeneratorJob.perform_now
    end

    assert_instance_of Hash, result
    assert_includes result, :patterns_processed
    assert_includes result, :transactions_generated
    assert_kind_of Integer, result[:patterns_processed]
    assert_kind_of Integer, result[:transactions_generated]
  end
end
