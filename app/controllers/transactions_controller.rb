class TransactionsController < ApplicationController
  include AccountLoadable
  include DateParseable
  include TransactionFilterable

  before_action :load_account_for_index, only: [ :index ]
  before_action :load_account, only: [ :show, :edit, :update, :destroy, :search ]
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
    @transactions = transaction_scope_for(@account, @filter_type)
                      .where(transaction_date: start_date..end_date)
                      .order(transaction_date: :desc)

    # Calculate totals and stats using service object (includes top merchants)
    stats = TransactionStatsCalculator.call(@account, start_date, end_date)
    @expense_total = stats[:expense_total]
    @income_total = stats[:income_total]
    @expense_count = stats[:expense_count]
    @income_count = stats[:income_count]
    @net_cash_flow = stats[:net_cash_flow]
    @transaction_count = stats[:transaction_count]
    @top_category = stats[:top_category]
    @top_category_amount = stats[:top_category_amount]
    @top_expense_merchants = stats[:top_expense_merchants]
    @top_income_merchants = stats[:top_income_merchants]

    respond_to do |format|
      format.html
      format.turbo_stream
    end
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
    result = Transactions::CreateService.call(
      account: @account,
      params: transaction_params.merge(transaction_type: params.dig(:transaction, :transaction_type)),
      transaction_type: params.dig(:transaction, :transaction_type)
    )

    if result.success?
      @transaction = result.transaction
      transaction_type = params.dig(:transaction, :transaction_type)
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
          upcoming_recurring = RecurringTransaction.upcoming_for_account(@account, Date.today.end_of_month)
          @upcoming_recurring_expenses = upcoming_recurring[:expenses]
          @upcoming_recurring_income = upcoming_recurring[:income]
          @upcoming_recurring_total = upcoming_recurring[:expense_total] + upcoming_recurring[:income_total]
        end
        format.html { redirect_back(fallback_location: root_path, notice: "#{type_name.capitalize} transaction added! Check the calendar to see its impact.") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("transactionModal", partial: "shared/transaction_drawer", locals: { default_transaction_date: Date.today }) }
        format.html { redirect_back(fallback_location: root_path, alert: "Error adding transaction: #{result.errors.full_messages.join(', ')}") }
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

  def search
    return unless load_account

    result = Transactions::SearchService.call(
      account: @account,
      query: params[:q],
      year: params[:year],
      month: params[:month]
    )

    @transactions = result.transactions
    stats = result.stats
    @expense_total = stats[:expense_total]
    @income_total = stats[:income_total]
    @expense_count = stats[:expense_count]
    @income_count = stats[:income_count]
    @net_cash_flow = stats[:net_cash_flow]
    @transaction_count = stats[:transaction_count]
    @top_category = stats[:top_category]
    @top_category_amount = stats[:top_category_amount]
    @top_expense_merchants = stats[:top_expense_merchants]
    @top_income_merchants = stats[:top_income_merchants]

    @filter_type = params[:q].to_s.strip.length >= 3 ? "search" : (params[:filter] || "all")

    respond_to do |format|
      format.turbo_stream
      format.json { render json: @transactions }
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

  # filtering handled by TransactionFilterable

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :transaction_date, :category, :merchant)
  end

  # upcoming recurring handled by RecurringTransaction.upcoming_for_account
end
