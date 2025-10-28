class RecurringTransactionsController < ApplicationController
  include AccountLoadable

  before_action :set_recurring_transaction, only: [ :show, :edit, :update, :destroy, :toggle_active ]

  def index
    return unless load_account

    @recurring_transactions = @account.recurring_transactions.order(created_at: :desc)

    # Calculate weekly and monthly breakdowns
    calculate_breakdowns
  end

  def calculate_breakdowns
    # Get active recurring transactions
    active = @account.recurring_transactions.active

    # Calculate weekly breakdown
    week_start = Date.today.beginning_of_week(:monday)
    week_end = Date.today.end_of_week(:monday)

    # Get recurring transactions due this week
    week_recurring = active.where("next_occurrence_date <= ? AND next_occurrence_date >= ?", week_end, week_start)

    @week_income = week_recurring.where(transaction_type: "income").sum(:amount)
    @week_expenses = week_recurring.where(transaction_type: "expense").sum(:amount).abs

    # Calculate monthly breakdown
    month_start = Date.today.beginning_of_month
    month_end = Date.today.end_of_month

    # Get recurring transactions due this month
    month_recurring = active.where("next_occurrence_date <= ? AND next_occurrence_date >= ?", month_end, month_start)

    @month_income = month_recurring.where(transaction_type: "income").sum(:amount)
    @month_expenses = month_recurring.where(transaction_type: "expense").sum(:amount).abs

    # Get next occurrence
    next_occurrence = active.where("next_occurrence_date >= ?", Date.today).order(:next_occurrence_date).first
    @next_occurrence_date = next_occurrence&.next_occurrence_date
    @next_occurrence_amount = next_occurrence&.amount
    @next_occurrence_desc = next_occurrence&.description
  end
  private :calculate_breakdowns

  def show
    # Recurring transaction is already loaded by before_action
  end

  def edit
    # Recurring transaction is already loaded by before_action
  end

  def update
    if @recurring.update(recurring_transaction_params)
      redirect_to @recurring, notice: "Recurring transaction updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
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

  private

  def set_recurring_transaction
    @recurring = @account.recurring_transactions.find(params[:id])
  end

  def recurring_transaction_params
    params.require(:recurring_transaction).permit(:description, :amount, :frequency, :next_occurrence_date, :transaction_type, :category, :merchant_pattern, :amount_tolerance, :projection_months, :is_active)
  end
end
