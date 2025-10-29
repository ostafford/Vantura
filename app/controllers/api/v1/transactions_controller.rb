# API controller for transactions
# Returns JSON responses matching ApiResponse<T> TypeScript interface
class Api::V1::TransactionsController < Api::V1::BaseController
  include DateParseable

  before_action :load_account, except: [:index]
  before_action :load_account_or_return, only: [:index]
  before_action :set_transaction, only: [:show, :update, :destroy]

  # GET /api/v1/transactions
  # GET /api/v1/transactions/:year/:month
  # Query params: filter, page, per_page
  def index
    return render_error(code: 'account_not_found', message: 'Account not found', status: :not_found) unless @account

    # Parse date parameters if provided
    if params[:year].present? && params[:month].present?
      parse_month_params
      start_date, end_date = month_date_range
    else
      # Default to current month if no date params
      @date = Date.today
      start_date = @date.beginning_of_month
      end_date = @date.end_of_month
    end

    # Get filter type from params, default to "all"
    filter_type = params[:filter] || "all"

    # Filter transactions
    transactions = filter_transactions_by_type(filter_type)
                     .where(transaction_date: start_date..end_date)
                     .order(transaction_date: :desc)

    # Pagination
    page = (params[:page] || 1).to_i
    per_page = [(params[:per_page] || 20).to_i, 100].min # Cap at 100
    offset = (page - 1) * per_page
    total = transactions.count
    paginated = transactions.limit(per_page).offset(offset)

    # Calculate stats using service object
    stats = TransactionStatsCalculator.call(@account, start_date, end_date)

    # Calculate top merchants
    top_expense_merchants = Transaction.top_merchants_by_type(
      "expense",
      account: @account,
      start_date: start_date,
      end_date: end_date,
      limit: 3
    )
    top_income_merchants = Transaction.top_merchants_by_type(
      "income",
      account: @account,
      start_date: start_date,
      end_date: end_date,
      limit: 3
    )

    # Build response with transactions and metadata
    render_success(
      {
        transactions: paginated.map(&:attributes),
        stats: stats.merge(
          top_expense_merchants: top_expense_merchants,
          top_income_merchants: top_income_merchants
        )
      },
      meta: pagination_meta(transactions, page: page, per_page: per_page, total: total)
    )
  end

  # GET /api/v1/transactions/:id
  def show
    render_success(@transaction.attributes)
  end

  # POST /api/v1/transactions
  def create
    return unless load_account

    @transaction = @account.transactions.build(transaction_params)
    @transaction.is_hypothetical = true
    @transaction.status = :hypothetical

    # Handle transaction type (expense or income)
    transaction_type = params[:transaction][:transaction_type] if params[:transaction]
    if transaction_type == "expense"
      # Expenses are negative
      @transaction.amount = -@transaction.amount.abs if @transaction.amount
    else
      # Income is positive
      @transaction.amount = @transaction.amount.abs if @transaction.amount
    end

    if @transaction.save
      render_success(@transaction.attributes, status: :created)
    else
      render_error(
        code: 'validation_error',
        message: 'Transaction validation failed',
        details: @transaction.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end

  # PATCH /api/v1/transactions/:id
  def update
    if @transaction.update(transaction_params)
      render_success(@transaction.attributes)
    else
      render_error(
        code: 'validation_error',
        message: 'Transaction validation failed',
        details: @transaction.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end

  # DELETE /api/v1/transactions/:id
  def destroy
    if @transaction.is_hypothetical
      @transaction.destroy
      render_success({ message: 'Transaction deleted successfully' })
    else
      render_error(
        code: 'not_allowed',
        message: 'Cannot delete real transactions from Up Bank',
        status: :forbidden
      )
    end
  end

  # GET /api/v1/transactions/search
  # Query params: q (search query), year, month
  def search
    return unless load_account

    query = params[:q].to_s.strip

    # Get the month/year from params
    if params[:year].present? && params[:month].present?
      @year = params[:year].to_i
      @month = params[:month].to_i
      @date = Date.new(@year, @month, 1)
      start_date = @date.beginning_of_month
      end_date = @date.end_of_month
    else
      # Default to current month
      @date = Date.today
      start_date = @date.beginning_of_month
      end_date = @date.end_of_month
    end

    if query.length >= 3
      # Use ILIKE for case-insensitive search in PostgreSQL
      search_pattern = "%#{query}%"
      transactions = @account.transactions
                             .where(transaction_date: start_date..end_date)
                             .where("description ILIKE ? OR category ILIKE ? OR merchant ILIKE ?",
                                    search_pattern, search_pattern, search_pattern)
                             .order(transaction_date: :desc)
                             .limit(10)

      # Calculate stats from search results
      expense_transactions = transactions.select { |t| t.amount < 0 }
      income_transactions = transactions.select { |t| t.amount > 0 }

      stats = {
        expense_total: expense_transactions.sum { |t| t.amount.abs },
        income_total: income_transactions.sum { |t| t.amount },
        expense_count: expense_transactions.count,
        income_count: income_transactions.count,
        net_cash_flow: income_transactions.sum(&:amount) - expense_transactions.sum { |t| t.amount.abs },
        transaction_count: transactions.count
      }

      # Top category from search results
      category_totals = transactions.group_by(&:category).transform_values do |txs|
        txs.sum(&:amount).abs
      end
      top_category_data = category_totals.max_by { |_, total| total }
      stats[:top_category] = top_category_data&.first || "N/A"
      stats[:top_category_amount] = top_category_data&.last || 0

      # Calculate top merchants from search results
      stats[:top_expense_merchants] = calculate_top_merchants(expense_transactions)
      stats[:top_income_merchants] = calculate_top_merchants(income_transactions)
    else
      # Return transactions for the selected month
      transactions = @account.transactions
                             .where(transaction_date: start_date..end_date)
                             .order(transaction_date: :desc)

      stats = TransactionStatsCalculator.call(@account, start_date, end_date)

      # Calculate top merchants
      stats[:top_expense_merchants] = Transaction.top_merchants_by_type(
        "expense",
        account: @account,
        start_date: start_date,
        end_date: end_date,
        limit: 3
      )
      stats[:top_income_merchants] = Transaction.top_merchants_by_type(
        "income",
        account: @account,
        start_date: start_date,
        end_date: end_date,
        limit: 3
      )
    end

    render_success({
      transactions: (transactions || []).map(&:attributes),
      stats: stats
    })
  end

  private

  def set_transaction
    @transaction = @account.transactions.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      code: 'not_found',
      message: 'Transaction not found',
      status: :not_found
    )
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

  def calculate_top_merchants(transactions)
    return [] if transactions.empty?

    merchants = transactions.group_by(&:merchant).transform_values do |txs|
      { total: txs.sum(&:amount).abs, count: txs.count }
    end

    merchants.sort_by { |_, data| -data[:total] }
             .first(3)
             .map do |merchant_name, data|
               {
                 merchant: merchant_name || "Unknown",
                 total: data[:total],
                 count: data[:count],
                 hypothetical: transactions.any? { |t| t.is_hypothetical? && t.merchant == merchant_name }
               }
             end
  end
end

