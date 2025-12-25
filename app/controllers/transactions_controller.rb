class TransactionsController < ApplicationController
  def index
    # Load filter options
    @categories = Category.joins(:transactions).where(transactions: { user_id: current_user.id }).distinct.order(:name)
    @accounts = current_user.accounts.order(:account_type, :display_name)

    @transactions = current_user.transactions
      .settled
      .includes(:account, :categories, :tags)
      .order(settled_at: :desc)

    # Filter by account (with ownership validation)
    if params[:account_id].present?
      account = current_user.accounts.find_by(id: params[:account_id])
      if account
        @transactions = @transactions.where(account: account)
      else
        flash[:alert] = "Account not found"
        redirect_to transactions_path
        return
      end
    end

    # Filter by category
    @transactions = @transactions.by_category(params[:category_id]) if params[:category_id].present?

    # Filter by date range
    if params[:start_date].present? || params[:end_date].present?
      start_date = params[:start_date]&.to_date || 12.months.ago
      end_date = params[:end_date]&.to_date || Date.current
      @transactions = @transactions.by_date_range(start_date, end_date)
    else
      # Default to recent (12 months) if no date filter
      @transactions = @transactions.recent
    end

    # Pagination (using limit for now, will add kaminari later)
    @transactions = @transactions.limit(100)
  end

  def show
    @transaction = current_user.transactions.includes(:account, :categories, :tags).find(params[:id])
  end

  def search
    # Load filter options (needed for partial rendering)
    @categories = Category.joins(:transactions).where(transactions: { user_id: current_user.id }).distinct.order(:name)
    @accounts = current_user.accounts.order(:account_type, :display_name)

    @transactions = current_user.transactions
      .settled
      .includes(:account, :categories, :tags)
      .order(settled_at: :desc)

    # Apply search query
    if params[:q].present?
      @transactions = @transactions.search(params[:q])
    end

    # Limit results
    @transactions = @transactions.limit(100)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("transactions", partial: "transaction_list")
      end
      format.html { render :index }
    end
  end
end

