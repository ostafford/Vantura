class Filter < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :name, presence: true
  validates :user_id, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }

  # JSONB fields with defaults
  attribute :filter_params, :jsonb, default: {}
  attribute :filter_types, :jsonb, default: {}
  attribute :date_range, :jsonb, default: {}

  # Apply filter to transactions using Transaction model scopes (DRY principle)
  def apply_to_transactions(transaction_scope = nil)
    scope = transaction_scope || user.transactions

    # Apply date range filter using by_date_range scope
    if date_range.present?
      start_date = date_range["start_date"]
      end_date = date_range["end_date"]

      if start_date.present? && end_date.present?
        scope = scope.by_date_range(Date.parse(start_date), Date.parse(end_date).end_of_day)
      elsif start_date.present?
        scope = scope.where("created_at >= ?", Date.parse(start_date))
      elsif end_date.present?
        scope = scope.where("created_at <= ?", Date.parse(end_date).end_of_day)
      end
    end

    # Apply filter_params using Transaction model scopes
    if filter_params.present?
      # Use model scopes for reusable filtering
      scope = scope.by_category(filter_params["category_id"])
      scope = scope.by_account(filter_params["account_id"])
      scope = scope.by_tag(filter_params["tag_id"])
      scope = scope.by_description(filter_params["search"])
      scope = scope.by_amount_range(filter_params["min_amount"], filter_params["max_amount"])

      # Transaction type filter
      if filter_params["transaction_type"].present?
        case filter_params["transaction_type"]
        when "income"
          scope = scope.income
        when "expense"
          scope = scope.expenses
        end
      end
    end

    scope
  end

  # Check if filter has any active filters
  def has_active_filters?
    (filter_params.present? && filter_params.any? { |_k, v| v.present? }) ||
      (date_range.present? && (date_range["start_date"].present? || date_range["end_date"].present?))
  end

  # Get filter summary for display
  def summary
    parts = []
    parts << "Category: #{Category.find(filter_params['category_id']).name}" if filter_params["category_id"].present?
    parts << "Type: #{filter_params['transaction_type']}" if filter_params["transaction_type"].present?
    parts << "Date: #{date_range['start_date']} to #{date_range['end_date']}" if date_range.present?
    parts.join(", ")
  end
end
