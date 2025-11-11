# Service Object: Get top merchants by transaction type within a date range
#
# Usage:
#   merchants = TransactionMerchantService.call(account, "expense", start_date, end_date, limit: 3)
#   merchants = TransactionMerchantService.call(account, "income", start_date, end_date)
#
# Returns: Array of merchant data with total, count, and hypothetical flag
#
class TransactionMerchantService < ApplicationService
  def initialize(account, transaction_type, start_date, end_date, limit: 3)
    @account = account
    @transaction_type = transaction_type
    @start_date = start_date
    @end_date = end_date
    @limit = limit
  end

  def call
    # Direct date range query - exclude hypothetical transactions for consistency
    relation = @account.transactions.real.where(transaction_date: @start_date..@end_date)

    # Filter by transaction type
    if @transaction_type == "expense"
      relation = relation.where("amount < 0")
    else # income
      relation = relation.where("amount > 0")
    end

    # Get top merchants
    merchants = relation.group(:merchant)
                       .select("merchant, SUM(amount) as total, COUNT(*) as count")
                       .order(@transaction_type == "expense" ? "total ASC" : "total DESC")
                       .limit(@limit)

    # Build hash with hypothetical flag
    merchants.map do |merchant|
      {
        merchant: merchant.merchant,
        total: merchant.total.abs,
        count: merchant.count,
        hypothetical: merchant_has_hypothetical?(merchant.merchant)
      }
    end
  end

  private

  # Check if a merchant has hypothetical transactions
  def merchant_has_hypothetical?(merchant_name)
    relation = @account.transactions
                      .where(transaction_date: @start_date..@end_date)
                      .where(merchant: merchant_name)
                      .where(is_hypothetical: true)

    if @transaction_type == "expense"
      relation = relation.where("amount < 0")
    else # income
      relation = relation.where("amount > 0")
    end

    relation.exists?
  end
end
