class RecurringTransactionsController < ApplicationController
  def index
    @account = Account.order(:created_at).last
    return redirect_to root_path, alert: "No account found" unless @account
    
    @recurring_transactions = @account.recurring_transactions.order(created_at: :desc)
  end
  
  def create
    @transaction = Transaction.find(params[:transaction_id])
    @account = @transaction.account
    
    # Create recurring transaction based on the selected transaction
    @recurring = @account.recurring_transactions.new(
      template_transaction_id: @transaction.id,
      description: @transaction.description,
      amount: @transaction.amount,
      category: @transaction.category,
      merchant_pattern: extract_merchant_pattern(@transaction.description),
      amount_tolerance: params[:amount_tolerance] || 1.0,
      frequency: params[:frequency],
      next_occurrence_date: params[:next_occurrence_date],
      transaction_type: @transaction.amount < 0 ? 'expense' : 'income',
      projection_months: params[:projection_months] || 'indefinite',
      is_active: true
    )
    
    if @recurring.save
      # Generate future hypothetical transactions
      months_ahead = @recurring.projection_months == 'indefinite' ? 12 : @recurring.projection_months.to_i
      RecurringTransactions::GenerateService.call(@recurring, months_ahead: months_ahead)
      
      redirect_back(
        fallback_location: root_path, 
        notice: "Recurring transaction created! Future occurrences have been added to your calendar."
      )
    else
      redirect_back(
        fallback_location: root_path,
        alert: "Error creating recurring transaction: #{@recurring.errors.full_messages.join(', ')}"
      )
    end
  end
  
  def destroy
    @recurring = RecurringTransaction.find(params[:id])
    
    # Delete all generated hypothetical transactions
    @recurring.generated_transactions.hypothetical.destroy_all
    
    # Delete the recurring pattern
    @recurring.destroy
    
    redirect_back(
      fallback_location: root_path,
      notice: "Recurring transaction removed. Future projections have been deleted."
    )
  end
  
  def toggle_active
    @recurring = RecurringTransaction.find(params[:id])
    @recurring.update(is_active: !@recurring.is_active)
    
    if @recurring.is_active?
      # Regenerate future transactions
      RecurringTransactions::GenerateService.call(@recurring)
      message = "Recurring transaction activated."
    else
      # Remove future transactions
      @recurring.generated_transactions.hypothetical.destroy_all
      message = "Recurring transaction paused."
    end
    
    redirect_back(fallback_location: root_path, notice: message)
  end
  
  private
  
  def extract_merchant_pattern(description)
    # Extract the key part of the merchant name for matching
    # Remove common patterns like numbers, dates, reference codes
    pattern = description.gsub(/\d{4,}/, '') # Remove long numbers
                        .gsub(/\s+\d+$/, '')  # Remove trailing numbers
                        .strip
    
    # Take the first significant word(s) as the pattern
    words = pattern.split
    words.first(2).join(' ') # Use first 1-2 words as pattern
  end
end

