module RecurringTransactions
  class GenerateService < ApplicationService
    def initialize(recurring_transaction, months_ahead: 6)
      @recurring = recurring_transaction
      @months_ahead = months_ahead
    end

    def call
      return { success: false, error: "Recurring transaction is not active" } unless @recurring.is_active?
      
      # Remove existing generated hypothetical transactions
      @recurring.generated_transactions.hypothetical.destroy_all
      
      generated_count = 0
      current_date = @recurring.next_occurrence_date
      end_date = Date.today + @months_ahead.months
      
      # Generate future occurrences
      while current_date <= end_date
        # Only generate if date is in the future
        if current_date > Date.today
          transaction = @recurring.account.transactions.create!(
            description: @recurring.description,
            amount: @recurring.amount,
            category: @recurring.category,
            transaction_date: current_date,
            status: 'HYPOTHETICAL',
            is_hypothetical: true,
            recurring_transaction_id: @recurring.id
          )
          generated_count += 1
        end
        
        # Calculate next occurrence
        current_date = @recurring.calculate_next_occurrence(current_date)
      end
      
      Rails.logger.info "Generated #{generated_count} future transactions for recurring pattern: #{@recurring.description}"
      
      { success: true, generated_count: generated_count }
    end
  end
end

