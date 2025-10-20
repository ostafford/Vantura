class DashboardController < ApplicationController
  def index
    # Get the first account (we'll handle multiple accounts later)
    @account = Account.order(:created_at).last

    if @account
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
      
      # Calculate End of Month balance
      future_transactions = @account.transactions
                                    .where('transaction_date > ? AND transaction_date <= ?', 
                                           @current_date, current_month_end)
      @end_of_month_balance = @account.current_balance + future_transactions.sum(:amount)
    end
  end

  def sync
    begin
      result = UpBank::SyncService.call
      
      if result[:success]
        redirect_to root_path, notice: "Successfully synced! Added #{result[:new_transactions]} new transactions."
      else
        redirect_to root_path, alert: "Sync failed: #{result[:error]}"
      end
    rescue StandardError => e
      redirect_to root_path, alert: "Sync failed: #{e.message}"
    end
  end
end
