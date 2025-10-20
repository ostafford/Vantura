class TransactionsController < ApplicationController
  def create
    @account = Account.order(:created_at).last
    
    if @account.nil?
      redirect_to root_path, alert: "Please sync your Up Bank account first."
      return
    end

    @transaction = @account.transactions.build(transaction_params)
    @transaction.is_hypothetical = true
    @transaction.status = :hypothetical
    
    # Convert to negative if it's an expense (positive amounts are expenses in our UI)
    if @transaction.amount && @transaction.amount > 0
      @transaction.amount = -@transaction.amount.abs
    end

    if @transaction.save
      redirect_back(fallback_location: root_path, notice: "Hypothetical transaction added! Check the calendar to see its impact.")
    else
      redirect_back(fallback_location: root_path, alert: "Error adding transaction: #{@transaction.errors.full_messages.join(', ')}")
    end
  end

  def destroy
    @transaction = Transaction.find(params[:id])
    
    if @transaction.is_hypothetical
      @transaction.destroy
      redirect_back(fallback_location: root_path, notice: "Hypothetical transaction removed.")
    else
      redirect_back(fallback_location: root_path, alert: "Cannot delete real transactions.")
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :transaction_date, :category)
  end
end

