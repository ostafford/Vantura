class DashboardController < ApplicationController
  def index
    # Get the first account (we'll handle multiple accounts later)
    @account = Account.order(:created_at).last

    if @account
      # Get recent transactions
      @recent_transactions = @account.transactions
                                     .order(transaction_date: :desc)
                                     .limit(10)

      # Calculate summary stats for current month
      current_month_start = Date.today.beginning_of_month
      current_month_end = Date.today.end_of_month
      
      @expense_count = @account.transactions.expenses.count
      @expense_total = @account.transactions.expenses.sum(:amount).abs
      
      @income_count = @account.transactions.income.count
      @income_total = @account.transactions.income.sum(:amount)
      
      # Calculate End of Month balance
      future_transactions = @account.transactions
                                    .where('transaction_date > ? AND transaction_date <= ?', 
                                           Date.today, current_month_end)
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
