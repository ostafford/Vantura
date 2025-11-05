class AnalysisController < ApplicationController
  include AccountLoadable

  # Security: Validate filter_id parameter
  before_action :validate_filter_id, only: [ :index ]

  def index
    load_account_or_return
    return unless @account

    # Set default date range (current month)
    @current_date = Date.current
    @selected_month = @current_date.month
    @selected_year = @current_date.year

    # Calculate analysis statistics using the same service as trends
    stats = TrendsStatsCalculator.call(@account)

    # Assign instance variables for view
    @current_month_income = stats[:current_month_income]
    @current_month_expenses = stats[:current_month_expenses]
    @net_savings = stats[:net_savings]
    @last_month_income = stats[:last_month_income]
    @last_month_expenses = stats[:last_month_expenses]
    @income_change_pct = stats[:income_change_pct]
    @expense_change_pct = stats[:expense_change_pct]
    @net_change_pct = stats[:net_change_pct]
    @top_merchant = stats[:top_merchant]

    # Get all transactions for the current month for detailed analysis
    # Use includes to prevent N+1 queries
    @transactions = @account.transactions
                          .includes(:account) # Eager load associations
                          .where(transaction_date: @current_date.beginning_of_month..@current_date.end_of_month)
                          .where(is_hypothetical: false)
                          .order(transaction_date: :desc)

    # Apply filter if one is selected
    if params[:filter_id].present?
      @selected_filter = Current.user.filters.find_by(id: params[:filter_id])
      if @selected_filter
        filtered_relation = TransactionFilterService.call(@account, @selected_filter)
        # Re-fetch only the filtered transactions for this account with eager loading
        @transactions = @account.transactions
                              .includes(:account)
                              .where(id: filtered_relation.select(:id))
      end
    end

    # Calculate breakdowns for ALL selected filter types
    @breakdowns = {}

    if @selected_filter&.filter_types&.present?
      # Calculate breakdown for each selected filter type
      filter_types = @selected_filter.filter_types

      filter_types.each do |filter_type|
        case filter_type
        when "merchant"
          @breakdowns["merchant"] = @transactions.group(:merchant).sum(:amount)
                                                  .sort_by { |_, amount| -amount.abs }
                                                  .to_h
        when "status"
          @breakdowns["status"] = @transactions.group(:status).sum(:amount)
                                               .sort_by { |_, amount| -amount.abs }
                                               .to_h
        when "category"
          @breakdowns["category"] = @transactions.group(:category).sum(:amount)
                                                .sort_by { |_, amount| -amount.abs }
                                                .to_h
        end
      end
    end

    # Always include category breakdown as default if no filter selected
    if @breakdowns.empty?
      @breakdowns["category"] = @transactions.group(:category).sum(:amount)
                                            .sort_by { |_, amount| -amount.abs }
                                            .to_h
    end

    # Pass all breakdowns to the view for dynamic card rendering
    @all_breakdowns = @breakdowns

    # Set the first breakdown as the primary one for backwards compatibility
    @breakdown_type = @breakdowns.keys.first || "category"
    @breakdown_data = @breakdowns[@breakdown_type] || {}

    # Keep legacy variables for compatibility (optimized with limit)
    @category_breakdown = @transactions.group(:category).sum(:amount)
    @merchant_breakdown = @transactions.group(:description).sum(:amount)
                                      .sort_by { |_, amount| -amount }
                                      .first(10)

    # Load user's custom filters with caching
    @custom_filters = Rails.cache.fetch("user_#{Current.user.id}_filters", expires_in: 5.minutes) do
      Current.user.filters.recent
    end

    # Load available filter options from database with caching
    if @account
      # Cache filter options for better performance
      cache_key = "account_#{@account.id}_filter_options"
      @available_categories, @available_merchants, @merchant_categories, @merchant_statuses, @category_statuses, @status_merchants, @status_categories = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        load_filter_options(@account)
      end

      # If editing a filter, filter merchants by selected categories
      if params[:filter_id].present? && @selected_filter
        categories = @selected_filter.filter_params["categories"]
        if categories.present? && categories.any?
          @available_merchants = @account.transactions
                                         .where(category: categories)
                                         .where.not(merchant: nil)
                                         .distinct
                                         .pluck(:merchant)
                                         .compact
                                         .sort
        end
      end
    else
      @available_categories = []
      @available_merchants = []
      @merchant_categories = {}
      @merchant_statuses = {}
      @category_statuses = {}
      @status_merchants = {}
      @status_categories = {}
    end
    @available_statuses = Transaction.statuses.keys
  end

  private

  # Security: Validate filter_id parameter to prevent unauthorized access
  def validate_filter_id
    if params[:filter_id].present?
      # Ensure filter_id is a valid integer
      unless params[:filter_id].match?(/\A\d+\z/)
        redirect_to analysis_path, alert: "Invalid filter ID"
        return
      end

      # Ensure the filter belongs to the current user
      filter = Current.user.filters.find_by(id: params[:filter_id])
      unless filter
        redirect_to analysis_path, alert: "Filter not found"
        nil
      end
    end
  end

  def load_filter_options(account)
    # Load available filter options from database
    available_categories = account.transactions.where.not(category: nil).distinct.pluck(:category).compact.sort
    available_merchants = account.transactions.where.not(merchant: nil).where.not(merchant: "").distinct.pluck(:merchant).compact.sort

    # Build comprehensive maps for dynamic filtering across all filter types
    merchant_categories = {}
    merchant_statuses = {}
    category_statuses = {}
    status_merchants = {}
    status_categories = {}

    # Get all unique combinations of merchant, category, and status
    # Use a single query to get all combinations
    combinations = account.transactions
                          .where.not(merchant: nil, category: nil)
                          .where.not(merchant: "")
                          .pluck(:merchant, :category, :status)
                          .uniq

    combinations.each do |merchant, category, status|
      # Build merchant -> categories map
      merchant_categories[merchant] ||= []
      merchant_categories[merchant] << category unless merchant_categories[merchant].include?(category)

      # Build merchant -> statuses map
      merchant_statuses[merchant] ||= []
      merchant_statuses[merchant] << status unless merchant_statuses[merchant].include?(status)

      # Build category -> statuses map
      category_statuses[category] ||= []
      category_statuses[category] << status unless category_statuses[category].include?(status)

      # Build status -> merchants map
      status_merchants[status] ||= []
      status_merchants[status] << merchant unless status_merchants[status].include?(merchant)

      # Build status -> categories map
      status_categories[status] ||= []
      status_categories[status] << category unless status_categories[status].include?(category)
    end

    [ available_categories, available_merchants, merchant_categories, merchant_statuses, category_statuses, status_merchants, status_categories ]
  end
end
