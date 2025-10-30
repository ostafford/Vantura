module TransactionFilterable
  extend ActiveSupport::Concern

  # Maps a filter type string ("expenses", "income", "hypothetical", or other) to
  # the appropriate transactions scope for the given account.
  # Returns an ActiveRecord::Relation scoped to the account.
  def transaction_scope_for(account, type)
    case type
    when "expenses"
      account.transactions.expenses
    when "income"
      account.transactions.income
    when "hypothetical"
      account.transactions.hypothetical
    else
      account.transactions
    end
  end
end


