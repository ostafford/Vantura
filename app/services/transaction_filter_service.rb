# Service Object: Apply a Filter object's criteria to transactions
#
# Usage:
#   filtered_transactions = TransactionFilterService.call(account, filter)
#
# Returns: Filtered ActiveRecord::Relation
#
class TransactionFilterService < ApplicationService
  def initialize(account, filter)
    @account = account
    @filter = filter
  end

  def call
    relation = @account.transactions

    # Apply date range filter
    if @filter.date_range.present?
      date_range = @filter.date_range
      if date_range["start_date"].present? && date_range["end_date"].present?
        relation = relation.in_date_range(date_range["start_date"], date_range["end_date"])
      end
    end

    # Apply filter type criteria
    @filter.filter_types.each do |filter_type|
      case filter_type
      when "category"
        if @filter.filter_params["categories"].present?
          relation = relation.by_categories(@filter.filter_params["categories"])
        end
      when "merchant"
        if @filter.filter_params["merchants"].present?
          relation = relation.by_merchants(@filter.filter_params["merchants"])
        end
      when "status"
        if @filter.filter_params["statuses"].present?
          relation = relation.by_statuses(@filter.filter_params["statuses"])
        end
      when "recurring_transactions"
        if @filter.filter_params["recurring_transactions"].present?
          relation = relation.by_recurring(@filter.filter_params["recurring_transactions"])
        end
      end
    end

    relation
  end
end
