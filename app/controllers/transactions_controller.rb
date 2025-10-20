class TransactionsController < ApplicationController
  def create
    @account = Account.order(:created_at).last

    if @account.nil?
      redirect_to root_path, alert: "Please sync your Up Bank account first."
      return
    end

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
      redirect_back(fallback_location: root_path, notice: "#{type_name.capitalize} transaction added! Check the calendar to see its impact.")
    else
      redirect_back(fallback_location: root_path, alert: "Error adding transaction: #{@transaction.errors.full_messages.join(', ')}")
    end
  end

  def all
    @account = Account.order(:created_at).last
    return redirect_to root_path, alert: "No account found" unless @account

    # Get year and month from params, default to current
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @date = Date.new(@year, @month, 1)

    # Get filter type from params, default to "all"
    @filter_type = params[:filter] || "all"

    # Filter transactions for this month
    start_date = @date.beginning_of_month
    end_date = @date.end_of_month

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
    @account = Account.order(:created_at).last
    return redirect_to root_path, alert: "No account found" unless @account

    # Get year and month from params, default to current
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @date = Date.new(@year, @month, 1)

    # Filter transactions for this month
    start_date = @date.beginning_of_month
    end_date = @date.end_of_month

    @transactions = @account.transactions.expenses
                            .where(transaction_date: start_date..end_date)
                            .order(transaction_date: :desc)
    @total_amount = @transactions.sum(:amount).abs
  end

  def income
    @account = Account.order(:created_at).last
    return redirect_to root_path, alert: "No account found" unless @account

    # Get year and month from params, default to current
    @year = params[:year]&.to_i || Date.today.year
    @month = params[:month]&.to_i || Date.today.month
    @date = Date.new(@year, @month, 1)

    # Filter transactions for this month
    start_date = @date.beginning_of_month
    end_date = @date.end_of_month

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
