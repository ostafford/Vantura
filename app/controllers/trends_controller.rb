class TrendsController < ApplicationController
  def index
    @account = Account.order(:created_at).last
    return redirect_to root_path, alert: "No account found" unless @account

    # Date range based on user selection (default last 12 months)
    @date_range = params[:date_range] || '12'
    end_date = Date.today.end_of_month
    
    case @date_range
    when 'all'
      # Get all transactions
      start_date = @account.transactions.minimum(:transaction_date) || (end_date - 11.months).beginning_of_month
    when '3'
      start_date = (end_date - 2.months).beginning_of_month
    when '6'
      start_date = (end_date - 5.months).beginning_of_month
    when '12'
      start_date = (end_date - 11.months).beginning_of_month
    when '24'
      start_date = (end_date - 23.months).beginning_of_month
    else
      start_date = (end_date - 11.months).beginning_of_month
    end

    @start_date = start_date
    @end_date = end_date

    scope = @account.transactions.where(transaction_date: start_date..end_date)

    # Monthly aggregates
    @monthly = scope.group_by { |t| t.transaction_date.beginning_of_month }
                    .sort_by { |month, _| month }
                    .map do |month, txns|
      income = txns.select { |t| t.amount > 0 }.sum(&:amount)
      expenses = txns.select { |t| t.amount < 0 }.sum(&:amount).abs
      {
        month: month,
        income: income,
        expenses: expenses,
        net: income - expenses
      }
    end

    # Get top merchants for filtering
    @top_merchants = scope.where(amount: ...0) # expenses only
                        .group(:merchant)
                        .sum(:amount)
                        .sort_by { |_, amount| amount.abs }
                        .reverse
                        .first(15)
                        .map { |merchant, _| merchant }

    # Get all categories for filtering
    @categories = scope.where(amount: ...0)
                      .pluck(:category)
                      .uniq
                      .compact
                      .sort

    # Multi-select filters
    @selected_merchants = params[:merchants].presence&.split(',') || []
    @selected_categories = params[:categories].presence&.split(',') || []
    @filter_type = params[:filter_type] || 'merchant' # 'merchant' or 'category'

    # Comparison data for selected items
    @comparison_data = []
    
    if @selected_merchants.any?
      @selected_merchants.each do |merchant|
        merchant_transactions = scope.where(merchant: merchant)
        monthly_data = merchant_transactions.group_by { |t| t.transaction_date.beginning_of_month }
                                            .sort_by { |month, _| month }
                                            .map do |month, txns|
          {
            month: month,
            amount: txns.sum(&:amount).abs,
            count: txns.count
          }
        end
        @comparison_data << {
          name: merchant,
          type: 'merchant',
          monthly: monthly_data,
          total: merchant_transactions.sum(&:amount).abs
        }
      end
    end

    if @selected_categories.any?
      @selected_categories.each do |category|
        category_transactions = scope.where(category: category)
        monthly_data = category_transactions.group_by { |t| t.transaction_date.beginning_of_month }
                                            .sort_by { |month, _| month }
                                            .map do |month, txns|
          {
            month: month,
            amount: txns.sum(&:amount).abs,
            count: txns.count
          }
        end
        @comparison_data << {
          name: category.humanize,
          type: 'category',
          monthly: monthly_data,
          total: category_transactions.sum(&:amount).abs
        }
      end
    end
  end
end


