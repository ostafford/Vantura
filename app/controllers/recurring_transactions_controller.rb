class RecurringTransactionsController < ApplicationController
  include AccountLoadable

  def index
    return unless load_account

    @recurring_transactions = @account.recurring_transactions.order(created_at: :desc)
  end

  def create
    @transaction = Transaction.find(params[:transaction_id])
    @account = @transaction.account

    # Create recurring transaction based on the selected transaction
    @recurring = @account.recurring_transactions.new(
      template_transaction_id: @transaction.id,
      description: @transaction.description,
      amount: @transaction.amount,
      category: @transaction.category,
      merchant_pattern: RecurringTransaction.extract_merchant_pattern(@transaction.description),
      amount_tolerance: params[:amount_tolerance] || 1.0,
      frequency: params[:frequency],
      next_occurrence_date: params[:next_occurrence_date],
      transaction_type: @transaction.transaction_type,
      projection_months: params[:projection_months] || "indefinite",
      is_active: true
    )

    if @recurring.save
      # Generate future hypothetical transactions
      months_ahead = @recurring.projection_months == "indefinite" ? 12 : @recurring.projection_months.to_i
      RecurringTransactions::GenerateService.call(@recurring, months_ahead: months_ahead)

      redirect_back(
        fallback_location: root_path,
        notice: "Recurring transaction created! Future occurrences have been added to your calendar."
      )
    else
      redirect_back(
        fallback_location: root_path,
        alert: "Error creating recurring transaction: #{@recurring.errors.full_messages.join(', ')}"
      )
    end
  end

  def destroy
    @recurring = RecurringTransaction.find(params[:id])

    # Delete all generated hypothetical transactions
    @recurring.generated_transactions.hypothetical.destroy_all

    # Delete the recurring pattern
    @recurring.destroy

    redirect_back(
      fallback_location: root_path,
      notice: "Recurring transaction removed. Future projections have been deleted."
    )
  end

  def toggle_active
    @recurring = RecurringTransaction.find(params[:id])
    @recurring.update(is_active: !@recurring.is_active)

    if @recurring.is_active?
      # Regenerate future transactions
      RecurringTransactions::GenerateService.call(@recurring)
      message = "Recurring transaction activated."
    else
      # Remove future transactions
      @recurring.generated_transactions.hypothetical.destroy_all
      message = "Recurring transaction paused."
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "recurring_transaction_#{@recurring.id}",
          partial: "recurring_transactions/recurring_transaction",
          locals: { recurring: @recurring }
        )
      end
      format.html { redirect_back(fallback_location: root_path, notice: message) }
    end
  end
end
