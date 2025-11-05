class TransactionsController < ApplicationController
  include AccountLoadable
  include DateParseable

  before_action :load_account_for_index, only: [ :index ]
  before_action :load_account, only: [ :show, :edit, :update, :destroy, :search ]
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]

  def index
    data = TransactionIndexService.call(@account, params[:filter] || "all", params.slice(:year, :month))
    assign_transaction_index_variables(data)
    respond_to { |format| format.html; format.turbo_stream }
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
    @transaction = build_transaction
    if @transaction.save
      handle_successful_create
    else
      handle_failed_create
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

  def search
    return unless load_account
    data = TransactionSearchService.call(@account, params[:q], params.slice(:year, :month), params[:filter] || "all")
    assign_transaction_index_variables(data)
    respond_to { |format| format.turbo_stream; format.json { render json: @transactions } }
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

  def assign_dashboard_stats
    stats = DashboardStatsCalculator.call(@account)
    @current_date, @recent_transactions = stats.values_at(:current_date, :recent_transactions)
    @expense_count, @expense_total, @income_count, @income_total = stats.values_at(:expense_count, :expense_total, :income_count, :income_total)
    @end_of_month_balance = stats[:end_of_month_balance]
    upcoming = RecurringTransactionsService.upcoming(@account, Date.today.end_of_month)
    @upcoming_recurring_expenses, @upcoming_recurring_income = upcoming.values_at(:expenses, :income)
    @upcoming_recurring_total = upcoming[:expense_total] + upcoming[:income_total]
  end

  def assign_transaction_index_variables(data)
    @transactions, @date, @year, @month, @filter_type = data.values_at(:transactions, :date, :year, :month, :filter_type)
    @expense_total, @income_total, @expense_count, @income_count = data.values_at(:expense_total, :income_total, :expense_count, :income_count)
    @net_cash_flow, @transaction_count, @top_category, @top_category_amount = data.values_at(:net_cash_flow, :transaction_count, :top_category, :top_category_amount)
    @top_expense_merchants, @top_income_merchants = data.values_at(:top_expense_merchants, :top_income_merchants)
  end

  def build_transaction
    transaction = @account.transactions.build(transaction_params)
    transaction.is_hypothetical = true
    transaction.status = :hypothetical
    transaction_type = params[:transaction][:transaction_type]
    transaction.amount = transaction_type == "expense" ? -transaction.amount.abs : transaction.amount.abs if transaction.amount
    transaction
  end

  def handle_successful_create
    type_name = params[:transaction][:transaction_type] == "expense" ? "expense" : "income"
    respond_to { |format| format.turbo_stream { assign_dashboard_stats }; format.html { redirect_back(fallback_location: root_path, notice: "#{type_name.capitalize} transaction added! Check the calendar to see its impact.") } }
  end

  def handle_failed_create
    respond_to { |format| format.turbo_stream { render turbo_stream: turbo_stream.replace("transactionModal", partial: "shared/transaction_drawer", locals: { default_transaction_date: Date.today }) }; format.html { redirect_back(fallback_location: root_path, alert: "Error adding transaction: #{@transaction.errors.full_messages.join(', ')}") } }
  end
end
