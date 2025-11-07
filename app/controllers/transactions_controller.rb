class TransactionsController < ApplicationController
  include AccountLoadable
  include DateParseable

  before_action :load_account_for_index, only: [ :index ]
  before_action :load_account, only: [ :show, :edit, :update, :destroy, :search ]
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]

  def index
    @transactions_data = TransactionIndexService.call(@account, params[:filter] || "all", params.slice(:year, :month))
    respond_to { |format| format.html; format.turbo_stream }
  end

  def show
    # Transaction is already loaded by before_action
    respond_to { |format| format.html }
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
    @transactions_data = TransactionSearchService.call(@account, params[:q], params.slice(:year, :month), params[:filter] || "all")
    respond_to do |format|
      format.html { redirect_to transactions_path(filter: @transactions_data[:filter_type], year: @transactions_data[:year], month: @transactions_data[:month], q: params[:q]) }
      format.turbo_stream
      format.json { render json: @transactions_data[:transactions] }
    end
  end

  private

  def load_account_for_index
    load_account_or_return
  end

  def set_transaction
    # First try to find transaction in user's accounts
    transaction = Transaction.joins(:account)
                             .where(accounts: { user_id: Current.user.id })
                             .find_by(id: params[:id])

    unless transaction
      head :forbidden
      return
    end

    @transaction = transaction
    # Set @account to the transaction's account for consistency
    @account = transaction.account
  end

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :transaction_date, :category, :merchant)
  end

  def assign_dashboard_stats
    stats = DashboardStatsCalculator.call(@account)
    upcoming = RecurringTransactionsService.upcoming(@account, Date.today.end_of_month)
    @dashboard_data = {
      current_date: stats[:current_date],
      recent_transactions: stats[:recent_transactions],
      expense_count: stats[:expense_count],
      expense_total: stats[:expense_total],
      income_count: stats[:income_count],
      income_total: stats[:income_total],
      end_of_month_balance: stats[:end_of_month_balance],
      upcoming_recurring_expenses: upcoming[:expenses],
      upcoming_recurring_income: upcoming[:income],
      upcoming_recurring_total: upcoming[:expense_total] + upcoming[:income_total]
    }
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
