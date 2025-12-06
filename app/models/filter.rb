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

  # Apply filter to transactions
  def apply_to_transactions(transaction_scope = nil)
    scope = transaction_scope || user.transactions

    # Apply date range filter
    if date_range.present?
      start_date = date_range["start_date"]
      end_date = date_range["end_date"]

      if start_date.present?
        scope = scope.where("created_at >= ?", Date.parse(start_date))
      end

      if end_date.present?
        scope = scope.where("created_at <= ?", Date.parse(end_date).end_of_day)
      end
    end

    # Apply filter_params
    if filter_params.present?
      # Category filter
      if filter_params["category_id"].present?
        scope = scope.where(category_id: filter_params["category_id"])
      end

      # Transaction type filter
      if filter_params["transaction_type"].present?
        case filter_params["transaction_type"]
        when "income"
          scope = scope.income
        when "expense"
          scope = scope.expenses
        end
      end

      # Amount range filter (handles both positive and negative amounts)
      if filter_params["min_amount"].present? || filter_params["max_amount"].present?
        min_cents = filter_params["min_amount"].present? ? (filter_params["min_amount"].to_f * 100).to_i : nil
        max_cents = filter_params["max_amount"].present? ? (filter_params["max_amount"].to_f * 100).to_i : nil

        # For expenses (negative), we check absolute value
        # For income (positive), we check actual value
        if min_cents && max_cents
          scope = scope.where(
            "(amount_cents >= ? AND amount_cents <= ?) OR (amount_cents <= ? AND amount_cents >= ?)",
            min_cents, max_cents, -min_cents, -max_cents
          )
        elsif min_cents
          scope = scope.where("(amount_cents >= ?) OR (amount_cents <= ?)", min_cents, -min_cents)
        elsif max_cents
          scope = scope.where("(amount_cents <= ?) OR (amount_cents >= ?)", max_cents, -max_cents)
        end
      end

      # Description/merchant search
      if filter_params["search"].present?
        search_term = "%#{filter_params["search"]}%"
        scope = scope.where("description ILIKE ?", search_term)
      end

      # Account filter
      if filter_params["account_id"].present?
        scope = scope.where(account_id: filter_params["account_id"])
      end

      # Tag filter
      if filter_params["tag_id"].present?
        scope = scope.joins(:transaction_tags)
                     .where(transaction_tags: { tag_id: filter_params["tag_id"] })
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
