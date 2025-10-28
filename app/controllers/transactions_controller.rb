class TransactionsController < ApplicationController
  include AccountLoadable
  include DateParseable

  before_action :load_account_for_index, only: [ :index ]
  before_action :load_account, only: [ :show, :edit, :update, :destroy ]
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]

  def index
    # Parse date parameters if provided
    if params[:year].present? && params[:month].present?
      parse_month_params
      start_date, end_date = month_date_range
      @date = Date.new(@year, @month, 1)
    else
      # Default to current month if no date params
      @date = Date.today
      @year = @date.year
      @month = @date.month
      start_date = @date.beginning_of_month
      end_date = @date.end_of_month
    end

    # Get filter type from params, default to "all"
    @filter_type = params[:filter] || "all"

    # Filter transactions
    @transactions = filter_transactions_by_type(@filter_type)
                      .where(transaction_date: start_date..end_date)
                      .order(transaction_date: :desc)

    # Calculate totals and stats using service object
    stats = TransactionStatsCalculator.call(@account, start_date, end_date)
    @expense_total = stats[:expense_total]
    @income_total = stats[:income_total]
    @expense_count = stats[:expense_count]
    @income_count = stats[:income_count]
    @net_cash_flow = stats[:net_cash_flow]
    @transaction_count = stats[:transaction_count]
    @top_category = stats[:top_category]
    @top_category_amount = stats[:top_category_amount]
  end

  def show
    # Transaction is already loaded by before_action
  end

  def edit
    # Transaction is already loaded by before_action
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: "Transaction updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    return unless load_account

    @transaction = @account.transactions.build(transaction_params)
    @transaction.is_hypothetical = true
    @transaction.status = :hypothetical

    # Handle transaction type (expense or income)
    transaction_type = params[:transaction][:transaction_type]
    if transaction_type == "expense"
      # Expenses are negative
      @transaction.amount = -@transaction.amount.abs if @transaction.amount
    else
      # Income is positive
      @transaction.amount = @transaction.amount.abs if @transaction.amount
    end

    if @transaction.save
      type_name = transaction_type == "expense" ? "expense" : "income"

      respond_to do |format|
        format.turbo_stream do
          # Calculate updated dashboard stats using service
          stats = DashboardStatsCalculator.call(@account)

          # Assign instance variables for Turbo Stream template
          @current_date = stats[:current_date]
          @recent_transactions = stats[:recent_transactions]
          @expense_count = stats[:expense_count]
          @expense_total = stats[:expense_total]
          @income_count = stats[:income_count]
          @income_total = stats[:income_total]
          @end_of_month_balance = stats[:end_of_month_balance]

          # Calculate upcoming recurring transactions for projection card
          upcoming_recurring = get_upcoming_recurring_transactions
          @upcoming_recurring_expenses = upcoming_recurring[:expenses]
          @upcoming_recurring_income = upcoming_recurring[:income]
          @upcoming_recurring_total = upcoming_recurring[:expense_total] + upcoming_recurring[:income_total]
        end
        format.html { redirect_back(fallback_location: root_path, notice: "#{type_name.capitalize} transaction added! Check the calendar to see its impact.") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("transactionModal", partial: "shared/transaction_drawer", locals: { default_transaction_date: Date.today }) }
        format.html { redirect_back(fallback_location: root_path, alert: "Error adding transaction: #{@transaction.errors.full_messages.join(', ')}") }
      end
    end
  end

  def destroy
    if @transaction.is_hypothetical
      @transaction.destroy
      redirect_back(fallback_location: root_path, notice: "Transaction removed.")
    else
      redirect_back(fallback_location: root_path, alert: "Cannot delete real transactions from Up Bank.")
    end
  end

  private

  def load_account_for_index
    load_account_or_return
    nil unless @account
  end

  def set_transaction
    @transaction = @account.transactions.find(params[:id])
  end

  def filter_transactions_by_type(type)
    case type
    when "expenses"
      @account.transactions.expenses
    when "income"
      @account.transactions.income
    when "hypothetical"
      @account.transactions.hypothetical
    else
      @account.transactions
    end
  end

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :transaction_date, :category, :merchant)
  end

  def get_upcoming_recurring_transactions
    # Get active recurring transactions that will occur before end of month
    end_of_month = Date.today.end_of_month

    upcoming = @account.recurring_transactions
                       .active
                       .where("next_occurrence_date <= ?", end_of_month)
                       .order(:next_occurrence_date)

    # Separate by type
    expenses = upcoming.select { |r| r.transaction_type_expense? }
    income = upcoming.select { |r| r.transaction_type_income? }

    {
      expenses: expenses,
      income: income,
      expense_total: expenses.sum { |r| r.amount.abs },
      income_total: income.sum { |r| r.amount }
    }
  end
  private :get_upcoming_recurring_transactions
end
