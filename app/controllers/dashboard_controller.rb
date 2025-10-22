class DashboardController < ApplicationController
  include AccountLoadable

  def index
    load_account_or_return
    return unless @account

    # Calculate summary stats for current month ONLY
    @current_date = Date.today
    current_month_start = @current_date.beginning_of_month
    current_month_end = @current_date.end_of_month

    # Get recent transactions for CURRENT MONTH ONLY
    @recent_transactions = @account.transactions
                                   .where(transaction_date: current_month_start..current_month_end)
                                   .order(transaction_date: :desc)
                                   .limit(10)

    # Current month expenses
    current_month_expenses = @account.transactions.expenses
                                     .where(transaction_date: current_month_start..current_month_end)
    @expense_count = current_month_expenses.count
    @expense_total = current_month_expenses.sum(:amount).abs

    # Current month income
    current_month_income = @account.transactions.income
                                   .where(transaction_date: current_month_start..current_month_end)
    @income_count = current_month_income.count
    @income_total = current_month_income.sum(:amount)

    # Calculate End of Month balance using Account model method
    @end_of_month_balance = @account.end_of_month_balance(@current_date)

    # Check if there's a sync result to display (shown after redirect from sync action)
    @sync_result = session.delete(:sync_result)
  end

  def sync
    unless Current.user.up_bank_token.present?
      redirect_to settings_path, alert: "Please configure your Up Bank token first."
      return
    end

    # Use Rails.error.handle to capture sync errors with user context
    result = Rails.error.handle(
      StandardError,
      context: { 
        user_id: Current.user.id,
        account_count: Current.user.accounts.count,
        action: "manual_sync"
      },
      fallback: -> { { success: false, error: "An unexpected error occurred during sync" } }
    ) do
      UpBank::SyncService.call(Current.user)
    end

    if result && result[:success]
      # Store sync result in session for after redirect
      session[:sync_result] = {
        success: true,
        new_transactions: result[:new_transactions],
        accounts: result[:accounts].count
      }
      redirect_to root_path, notice: "Successfully synced! Added #{result[:new_transactions]} new transactions."
    else
      redirect_to root_path, alert: "Sync failed: #{result[:error] || 'An unexpected error occurred'}"
    end
  end
end
