# API controller for transactions
# Returns JSON responses matching ApiResponse<T> TypeScript interface
class Api::V1::TransactionsController < Api::V1::BaseController
  include DateParseable
  include TransactionFilterable

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
    transactions = transaction_scope_for(@account, filter_type)
                     .where(transaction_date: start_date..end_date)
                     .order(transaction_date: :desc)

    # Pagination
    page = (params[:page] || 1).to_i
    per_page = [(params[:per_page] || 20).to_i, 100].min # Cap at 100
    offset = (page - 1) * per_page
    total = transactions.count
    paginated = transactions.limit(per_page).offset(offset)

    # Calculate stats using service object (includes top merchants)
    stats = TransactionStatsCalculator.call(@account, start_date, end_date)

    # Build response with transactions and metadata
    render_success(
      {
        transactions: paginated.map(&:attributes),
        stats: stats
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

    result = Transactions::CreateService.call(
      account: @account,
      params: transaction_params.merge(transaction_type: params.dig(:transaction, :transaction_type)),
      transaction_type: params.dig(:transaction, :transaction_type)
    )

    if result.success?
      render_success(result.transaction.attributes, status: :created)
    else
      render_error(
        code: 'validation_error',
        message: 'Transaction validation failed',
        details: result.errors.as_json,
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

    result = Transactions::SearchService.call(
      account: @account,
      query: params[:q],
      year: params[:year],
      month: params[:month]
    )

    render_success({
      transactions: result.transactions.map(&:attributes),
      stats: result.stats
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

  # filtering handled by TransactionFilterable

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :transaction_date, :category, :merchant)
  end

  # search aggregation handled by Transactions::SearchService
end

