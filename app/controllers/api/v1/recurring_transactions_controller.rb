# API controller for recurring transactions
class Api::V1::RecurringTransactionsController < Api::V1::BaseController
  before_action :load_account, except: [:index]
  before_action :load_account_or_return, only: [:index]
  before_action :set_recurring_transaction, only: [:show, :update, :destroy, :toggle_active]

  # GET /api/v1/recurring_transactions
  def index
    return render_error(code: 'account_not_found', message: 'Account not found', status: :not_found) unless @account

    recurring_transactions = @account.recurring_transactions.order(created_at: :desc)

    # Calculate breakdowns
    active = @account.recurring_transactions.active
    week_start = Date.today.beginning_of_week(:monday)
    week_end = Date.today.end_of_week(:monday)
    week_recurring = active.where("next_occurrence_date <= ? AND next_occurrence_date >= ?", week_end, week_start)

    month_start = Date.today.beginning_of_month
    month_end = Date.today.end_of_month
    month_recurring = active.where("next_occurrence_date <= ? AND next_occurrence_date >= ?", month_end, month_start)

    next_occurrence = active.where("next_occurrence_date >= ?", Date.today).order(:next_occurrence_date).first

    render_success({
      recurring_transactions: recurring_transactions.map(&:attributes),
      breakdowns: {
        week_income: week_recurring.where(transaction_type: "income").sum(:amount),
        week_expenses: week_recurring.where(transaction_type: "expense").sum(:amount).abs,
        month_income: month_recurring.where(transaction_type: "income").sum(:amount),
        month_expenses: month_recurring.where(transaction_type: "expense").sum(:amount).abs,
        next_occurrence_date: next_occurrence&.next_occurrence_date,
        next_occurrence_amount: next_occurrence&.amount,
        next_occurrence_desc: next_occurrence&.description
      }
    })
  end

  # GET /api/v1/recurring_transactions/:id
  def show
    render_success(@recurring.attributes)
  end

  # POST /api/v1/recurring_transactions
  def create
    return unless load_account

    # If creating from a transaction template
    if params[:transaction_id].present?
      template_transaction = Transaction.find(params[:transaction_id])
      unless template_transaction.account_id == @account.id
        return render_error(code: 'unauthorized', message: 'Transaction does not belong to your account', status: :forbidden)
      end

      @recurring = @account.recurring_transactions.new(
        template_transaction_id: template_transaction.id,
        description: template_transaction.description,
        amount: template_transaction.amount,
        category: template_transaction.category,
        merchant_pattern: RecurringTransaction.extract_merchant_pattern(template_transaction.description),
        amount_tolerance: params[:amount_tolerance] || 1.0,
        frequency: params[:frequency],
        next_occurrence_date: params[:next_occurrence_date],
        transaction_type: template_transaction.transaction_type,
        projection_months: params[:projection_months] || "indefinite",
        is_active: true
      )
    else
      @recurring = @account.recurring_transactions.build(recurring_transaction_params)
    end

    if @recurring.save
      # Generate future hypothetical transactions
      months_ahead = @recurring.projection_months == "indefinite" ? 12 : @recurring.projection_months.to_i
      RecurringTransactions::GenerateService.call(@recurring, months_ahead: months_ahead)

      render_success(@recurring.attributes, status: :created)
    else
      render_error(
        code: 'validation_error',
        message: 'Recurring transaction validation failed',
        details: @recurring.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end

  # PATCH /api/v1/recurring_transactions/:id
  def update
    if @recurring.update(recurring_transaction_params)
      render_success(@recurring.attributes)
    else
      render_error(
        code: 'validation_error',
        message: 'Recurring transaction validation failed',
        details: @recurring.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end

  # DELETE /api/v1/recurring_transactions/:id
  def destroy
    # Delete all generated hypothetical transactions
    @recurring.generated_transactions.hypothetical.destroy_all
    @recurring.destroy

    render_success({ message: 'Recurring transaction deleted successfully' })
  end

  # POST /api/v1/recurring_transactions/:id/toggle_active
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

    render_success({
      recurring_transaction: @recurring.attributes,
      message: message
    })
  end

  private

  def set_recurring_transaction
    @recurring = @account.recurring_transactions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      code: 'not_found',
      message: 'Recurring transaction not found',
      status: :not_found
    )
  end

  def recurring_transaction_params
    params.require(:recurring_transaction).permit(
      :description, :amount, :frequency, :next_occurrence_date,
      :transaction_type, :category, :merchant_pattern, :amount_tolerance,
      :projection_months, :is_active
    )
  end
end

