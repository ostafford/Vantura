class TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @transactions = apply_filters(current_user.transactions.includes(:account, :category))
    @pagy, @transactions = pagy(:offset, @transactions, items: 20)
  end

  def show
    @transaction = current_user.transactions.find(params[:id])
  end

  def update
    @transaction = current_user.transactions.find(params[:id])

    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: "Transaction updated successfully."
    else
      redirect_to @transaction, alert: @transaction.errors.full_messages.join(", ")
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(:category_id, :notes, tag_ids: [])
  end

  def apply_filters(scope)
    scope = scope.recent # Default ordering

    # Use model scopes for filtering (DRY principle)
    scope = scope.by_category(params[:category_id])
    scope = scope.by_account(params[:account_id])
    scope = scope.by_tag(params[:tag_id])
    scope = scope.by_description(params[:search])
    scope = scope.by_amount_range(params[:min_amount], params[:max_amount])

    # Transaction type filter (income/expense)
    if params[:transaction_type].present?
      case params[:transaction_type].downcase
      when "income"
        scope = scope.income
      when "expense"
        scope = scope.expenses
      end
    end

    # Date range filter - use by_date_range scope if both dates present, otherwise handle separately
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date]).end_of_day
      scope = scope.by_date_range(start_date, end_date)
    elsif params[:start_date].present?
      scope = scope.where("created_at >= ?", Date.parse(params[:start_date]))
    elsif params[:end_date].present?
      scope = scope.where("created_at <= ?", Date.parse(params[:end_date]).end_of_day)
    end

    scope
  end
end
