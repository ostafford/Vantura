# Service Object: Broadcast dashboard updates when sync completes or data changes
#
# Usage:
#   DashboardBroadcastService.call(account)
#
# Broadcasts Turbo Stream updates to update all dashboard cards in real-time
#
class DashboardBroadcastService < ApplicationService
  def initialize(account)
    @account = account
    @user = account.user
  end

  def call
    return unless @user # Ensure we have a user to broadcast to

    # Calculate dashboard stats (bypass cache for fresh data)
    stats = DashboardStatsCalculator.call(@account)

    current_date = stats[:current_date]
    expense_count = stats[:expense_count]
    expense_total = stats[:expense_total]
    income_count = stats[:income_count]
    income_total = stats[:income_total]
    end_of_month_balance = stats[:end_of_month_balance]
    top_expense_merchants = stats[:top_expense_merchants] || []
    top_income_merchants = stats[:top_income_merchants] || []

    # Get upcoming recurring transactions
    upcoming = RecurringTransactionsService.upcoming(@account, Date.today.end_of_month)
    upcoming_recurring_expenses = upcoming[:expenses]
    upcoming_recurring_income = upcoming[:income]
    upcoming_recurring_total = upcoming[:expense_total] + upcoming[:income_total]

    # Get current week transactions for recent transactions table
    recent_transactions = get_current_week_transactions

    # Broadcast updates to all dashboard cards using Turbo Streams
    broadcast_hero_card(current_date)
    broadcast_expenses_card(expense_total, expense_count, current_date, top_expense_merchants)
    broadcast_income_card(income_total, income_count, current_date, top_income_merchants)
    broadcast_projection_card(income_total, expense_total, end_of_month_balance, current_date, upcoming_recurring_expenses, upcoming_recurring_income, upcoming_recurring_total)
    broadcast_net_cash_flow_card(income_total, expense_total, expense_count, income_count, current_date)
    broadcast_recent_transactions(recent_transactions)
  end

  private

  def broadcast_hero_card(current_date)
    # Hero card needs to be rendered with account data and progress indicator
    html = ApplicationController.render(
      partial: "dashboard/hero_card_with_progress",
      locals: {
        account: @account,
        current_date: current_date
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      @user,
      target: "dashboard-current-balance-card",
      html: html
    )
  end

  def broadcast_expenses_card(expense_total, expense_count, current_date, top_expense_merchants)
    html = ApplicationController.render(
      partial: "shared/bento_cards/transaction_type_card",
      locals: {
        type: "expense",
        expense_total: expense_total,
        expense_count: expense_count,
        current_date: current_date,
        top_expense_merchants: top_expense_merchants
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      @user,
      target: "dashboard-expenses-card",
      html: html
    )
  end

  def broadcast_income_card(income_total, income_count, current_date, top_income_merchants)
    html = ApplicationController.render(
      partial: "shared/bento_cards/transaction_type_card",
      locals: {
        type: "income",
        income_total: income_total,
        income_count: income_count,
        current_date: current_date,
        top_income_merchants: top_income_merchants
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      @user,
      target: "dashboard-income-card",
      html: html
    )
  end

  def broadcast_projection_card(income_total, expense_total, end_of_month_balance, current_date, upcoming_recurring_expenses, upcoming_recurring_income, upcoming_recurring_total)
    html = ApplicationController.render(
      partial: "dashboard/projection_card",
      locals: {
        income_total: income_total,
        expense_total: expense_total,
        end_of_month_balance: end_of_month_balance,
        current_date: current_date,
        upcoming_recurring_expenses: upcoming_recurring_expenses,
        upcoming_recurring_income: upcoming_recurring_income,
        upcoming_recurring_total: upcoming_recurring_total
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      @user,
      target: "dashboard-projection-card",
      html: html
    )
  end

  def broadcast_net_cash_flow_card(income_total, expense_total, expense_count, income_count, current_date)
    html = ApplicationController.render(
      partial: "dashboard/net_cash_flow_card",
      locals: {
        income_total: income_total,
        expense_total: expense_total,
        expense_count: expense_count,
        income_count: income_count,
        current_date: current_date
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      @user,
      target: "dashboard-net-cash-flow-card",
      html: html
    )
  end

  def broadcast_recent_transactions(transactions)
    # Replace the entire table body with updated transactions
    html = ApplicationController.render(
      partial: "dashboard/recent_transactions_table_body",
      locals: {
        recent_transactions: transactions
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      @user,
      target: "dashboard-recent-transactions-table-body",
      html: html
    )
  end

  def get_current_week_transactions
    week_start = Date.today.beginning_of_week(:monday)
    week_end = Date.today.end_of_week(:monday)
    @account.transactions
            .where(transaction_date: week_start..week_end)
            .includes(:recurring_transaction)
            .order(transaction_date: :desc, id: :desc)
  end

  def formatted_balance(balance)
    "$#{ApplicationController.helpers.number_with_precision(balance, precision: 2)}"
  end
end
