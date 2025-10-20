class DashboardController < ApplicationController
  def index
    # Get the first account (we'll handle multiple accounts later)
    @account = Account.order(:created_at).last

    if @account
      # Get recent transactions
      @recent_transactions = @account.transactions
                                     .order(transaction_date: :desc)
                                     .limit(10)

      # Calculate summary stats
      @total_transactions = @account.transactions.count
      @expense_count = @account.transactions.expenses.count
      @income_count = @account.transactions.income.count
      @hypothetical_count = @account.transactions.hypothetical.count
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
