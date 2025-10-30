module RecurringTransactions
  class Projector
    # Projects recurring transactions into the given window.
    # Currently delegates to the single source of truth on the model to avoid duplication.
    #
    # @param account [Account]
    # @param start_date [Date]
    # @param end_date [Date]
    # @return [Hash] { expenses:, income:, expense_total:, income_total: }
    def self.call(account:, start_date:, end_date:)
      # For now, we rely on upcoming_for_account which already filters by <= end_date.
      # If we later need to consider start_date exclusivity, extend logic here.
      RecurringTransaction.upcoming_for_account(account, end_date)
    end
  end
end


