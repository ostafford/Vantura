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

    # Category filter
    if params[:category_id].present?
      scope = scope.where(category_id: params[:category_id])
    end

    # Transaction type filter (income/expense)
    if params[:transaction_type].present?
      case params[:transaction_type].downcase
      when "income"
        scope = scope.income
      when "expense"
        scope = scope.expenses
      end
    end

    # Date range filter
    if params[:start_date].present?
      scope = scope.where("created_at >= ?", Date.parse(params[:start_date]))
    end

    if params[:end_date].present?
      scope = scope.where("created_at <= ?", Date.parse(params[:end_date]).end_of_day)
    end

    # Amount range filter
    if params[:min_amount].present?
      min_cents = (params[:min_amount].to_f * 100).to_i
      scope = scope.where("ABS(amount_cents) >= ?", min_cents)
    end

    if params[:max_amount].present?
      max_cents = (params[:max_amount].to_f * 100).to_i
      scope = scope.where("ABS(amount_cents) <= ?", max_cents)
    end

    # Search filter (description or message)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      scope = scope.where(
        "description ILIKE ? OR message ILIKE ?",
        search_term, search_term
      )
    end

    # Account filter
    if params[:account_id].present?
      scope = scope.where(account_id: params[:account_id])
    end

    # Tag filter
    if params[:tag_id].present?
      scope = scope.joins(:transaction_tags)
                   .where(transaction_tags: { tag_id: params[:tag_id] })
                   .distinct
    end

    scope
  end
end
