class RecurringTransactions::CreateFromTemplateService < ApplicationService
  Result = Struct.new(:success?, :recurring, :errors)

  def initialize(transaction:, frequency:, next_occurrence_date:, amount_tolerance: 1.0, projection_months: "indefinite")
    @source_transaction = transaction
    @account = transaction.account
    @frequency = frequency
    @next_occurrence_date = next_occurrence_date
    @amount_tolerance = amount_tolerance
    @projection_months = projection_months
  end

  def call
    recurring = @account.recurring_transactions.new(
      template_transaction_id: @source_transaction.id,
      description: @source_transaction.description,
      amount: @source_transaction.amount,
      category: @source_transaction.category,
      merchant_pattern: RecurringTransaction.extract_merchant_pattern(@source_transaction.description),
      amount_tolerance: @amount_tolerance || 1.0,
      frequency: @frequency,
      next_occurrence_date: @next_occurrence_date,
      transaction_type: @source_transaction.transaction_type,
      projection_months: @projection_months || "indefinite",
      is_active: true
    )

    if recurring.save
      months_ahead = recurring.projection_months == "indefinite" ? 12 : recurring.projection_months.to_i
      RecurringTransactions::GenerateService.call(recurring, months_ahead: months_ahead)
      Result.new(true, recurring, nil)
    else
      Result.new(false, recurring, recurring.errors)
    end
  end
end


