class TransactionsController < ApplicationController
  include AccountLoadable
  include DateParseable

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

  def all
    return unless load_account

    # Parse date parameters
    parse_month_params

    # Get filter type from params, default to "all"
    @filter_type = params[:filter] || "all"

    # Filter transactions for this month
    start_date, end_date = month_date_range

    @transactions = @account.transactions
                            .where(transaction_date: start_date..end_date)

    # Apply filter based on type
    case @filter_type
    when "expenses"
      @transactions = @transactions.expenses
    when "income"
      @transactions = @transactions.income
    when "hypothetical"
      @transactions = @transactions.hypothetical
      # "all" - no additional filter needed
    end

    @transactions = @transactions.order(transaction_date: :desc)

    # Calculate totals
    @expense_total = @account.transactions.expenses
                             .where(transaction_date: start_date..end_date)
                             .sum(:amount).abs
    @income_total = @account.transactions.income
                            .where(transaction_date: start_date..end_date)
                            .sum(:amount)
  end

  def expenses
    return unless load_account

    # Parse date parameters
    parse_month_params

    # Filter transactions for this month
    start_date, end_date = month_date_range

    @transactions = @account.transactions.expenses
                            .where(transaction_date: start_date..end_date)
                            .order(transaction_date: :desc)
    @total_amount = @transactions.sum(:amount).abs
  end

  def income
    return unless load_account

    # Parse date parameters
    parse_month_params

    # Filter transactions for this month
    start_date, end_date = month_date_range

    @transactions = @account.transactions.income
                            .where(transaction_date: start_date..end_date)
                            .order(transaction_date: :desc)
    @total_amount = @transactions.sum(:amount)
  end

  def destroy
    @transaction = Transaction.find(params[:id])

    if @transaction.is_hypothetical
      @transaction.destroy
      redirect_back(fallback_location: root_path, notice: "Transaction removed.")
    else
      redirect_back(fallback_location: root_path, alert: "Cannot delete real transactions from Up Bank.")
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :transaction_date, :category)
  end
end
