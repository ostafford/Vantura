class TransactionsController < ApplicationController
  before_action :authenticate_user!

  def index
    @transactions = apply_filters(policy_scope(Transaction).includes(:account, :category, :tags))
    @pagy, @transactions = pagy(:offset, @transactions, items: 20)
    @summary_stats = calculate_summary_stats(@transactions)
  end

  def show
    @transaction = current_user.transactions.find(params[:id])
    authorize @transaction

    # Support both regular page request and modal request
    if request.headers["Turbo-Frame"].present?
      render layout: false
    end
  end

  def update
    @transaction = current_user.transactions.find(params[:id])
    authorize @transaction

    if @transaction.update(transaction_params)
      # Broadcast update via Turbo Stream
      broadcast_transaction_update(@transaction)

      redirect_to @transaction, notice: I18n.t("flash.transactions.updated")
    else
      redirect_to @transaction, alert: @transaction.errors.full_messages.join(", ")
    end
  end

  def export
    @transactions = apply_filters(policy_scope(Transaction).includes(:account, :category, :tags))

    respond_to do |format|
      format.csv do
        send_data generate_csv(@transactions),
                  filename: "transactions-#{Date.current.strftime('%Y%m%d')}.csv",
                  type: "text/csv"
      end
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

  def calculate_summary_stats(transactions)
    return default_stats if transactions.empty?

    income = transactions.select { |t| t.amount_cents > 0 }
    expenses = transactions.select { |t| t.amount_cents < 0 }

    income_total = income.sum(&:amount_cents)
    expenses_total = expenses.sum(&:amount_cents)
    net = income_total + expenses_total # expenses_total is already negative

    {
      count: transactions.count,
      income_total: income_total,
      expenses_total: expenses_total,
      net: net,
      average_amount: transactions.present? ? (transactions.sum(&:amount_cents) / transactions.count.to_f) : 0
    }
  end

  def default_stats
    {
      count: 0,
      income_total: 0,
      expenses_total: 0,
      net: 0,
      average_amount: 0
    }
  end

  def generate_csv(transactions)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [
        "Date",
        "Settled Date",
        "Description",
        "Amount (AUD)",
        "Category",
        "Tags",
        "Account",
        "Status",
        "Notes",
        "Raw Text"
      ]

      transactions.each do |transaction|
        csv << [
          transaction.created_at_up&.strftime("%Y-%m-%d") || transaction.created_at.strftime("%Y-%m-%d"),
          transaction.settled_at&.strftime("%Y-%m-%d"),
          transaction.description,
          format("%.2f", transaction.amount_cents / 100.0),
          transaction.category&.name,
          transaction.tags.pluck(:name).join(", "),
          transaction.account.display_name,
          transaction.status,
          transaction.notes,
          transaction.raw_text
        ]
      end
    end
  end

  def broadcast_transaction_update(transaction)
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{transaction.user_id}_transactions",
      target: "transaction-#{transaction.id}",
      partial: "transactions/transaction_item",
      locals: { transaction: transaction }
    )
  rescue => e
    Rails.logger.error "Failed to broadcast transaction update: #{e.message}"
  end
end
