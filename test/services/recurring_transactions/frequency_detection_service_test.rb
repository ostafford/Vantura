require "test_helper"

module RecurringTransactions
  class FrequencyDetectionServiceTest < ActiveSupport::TestCase
    def setup
      @account = accounts(:one)
      @transaction = @account.transactions.create!(
        description: "Netflix Subscription",
        amount: -15.0,
        transaction_date: Date.today,
        status: "SETTLED",
        is_hypothetical: false
      )
    end

    test "returns hash with frequency and confidence" do
      result = FrequencyDetectionService.call(@account, @transaction)

      assert_instance_of Hash, result
      assert_includes result, :frequency
      assert_includes result, :confidence
    end

    test "returns nil frequency when no similar transactions found" do
      result = FrequencyDetectionService.call(@account, @transaction)

      assert_nil result[:frequency]
      assert_equal 0, result[:confidence]
    end

    test "detects monthly frequency from transaction history" do
      # Create monthly transactions
      base_date = Date.today - 3.months
      4.times do |i|
        @account.transactions.create!(
          description: "Netflix Subscription",
          amount: -15.0,
          transaction_date: base_date + i.months,
          status: "SETTLED",
          is_hypothetical: false
        )
      end

      result = FrequencyDetectionService.call(@account, @transaction)

      assert_equal "monthly", result[:frequency]
      assert result[:confidence] > 0
    end

    test "detects weekly frequency from transaction history" do
      # Create weekly transactions
      base_date = Date.today - 3.weeks
      4.times do |i|
        @account.transactions.create!(
          description: "Coffee Shop",
          amount: -5.0,
          transaction_date: base_date + i.weeks,
          status: "SETTLED",
          is_hypothetical: false
        )
      end

      coffee_transaction = @account.transactions.create!(
        description: "Coffee Shop",
        amount: -5.0,
        transaction_date: Date.today,
        status: "SETTLED",
        is_hypothetical: false
      )

      result = FrequencyDetectionService.call(@account, coffee_transaction)

      assert_equal "weekly", result[:frequency]
      assert result[:confidence] > 0
    end

  test "requires at least 2 similar transactions" do
    # Clear existing transactions first
    @account.transactions.destroy_all

    # Create transaction with unique description that won't match anything
    transaction = @account.transactions.create!(
      description: "Unique Transaction #{Time.now.to_i}",
      amount: -15.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    result = FrequencyDetectionService.call(@account, transaction)

    assert_nil result[:frequency]
    assert_equal 0, result[:confidence]
  end

    test "matches transactions by merchant pattern and similar amount" do
      # Create transactions with similar merchant pattern
      @account.transactions.create!(
        description: "Netflix Subscription Payment",
        amount: -15.0,
        transaction_date: Date.today - 1.month,
        status: "SETTLED",
        is_hypothetical: false
      )

      @account.transactions.create!(
        description: "Netflix Subscription Payment",
        amount: -15.0,
        transaction_date: Date.today - 2.months,
        status: "SETTLED",
        is_hypothetical: false
      )

      result = FrequencyDetectionService.call(@account, @transaction)

      assert_equal "monthly", result[:frequency]
    end

    test "does not match transactions with very different amounts" do
      # Create transaction with different amount (more than 10% difference)
      @account.transactions.create!(
        description: "Netflix Subscription",
        amount: -50.0, # Very different amount
        transaction_date: Date.today - 1.month,
        status: "SETTLED",
        is_hypothetical: false
      )

      result = FrequencyDetectionService.call(@account, @transaction)

      assert_nil result[:frequency]
    end

    test "calculates confidence based on match count" do
      # Create multiple monthly transactions
      base_date = Date.today - 5.months
      6.times do |i|
        @account.transactions.create!(
          description: "Netflix Subscription",
          amount: -15.0,
          transaction_date: base_date + i.months,
          status: "SETTLED",
          is_hypothetical: false
        )
      end

      result = FrequencyDetectionService.call(@account, @transaction)

      assert_equal "monthly", result[:frequency]
      # More matches should give higher confidence
      assert result[:confidence] >= 50
    end

  test "handles transactions with blank merchant pattern" do
    # Create transaction with description that won't match pattern
    transaction = @account.transactions.create!(
      description: "12345", # Will result in blank pattern
      amount: -15.0,
      transaction_date: Date.today,
      status: "SETTLED",
      is_hypothetical: false
    )

    result = FrequencyDetectionService.call(@account, transaction)

    assert_nil result[:frequency]
    assert_equal 0, result[:confidence]
  end
  end
end
