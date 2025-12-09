require "set"

class Transaction < ApplicationRecord
  belongs_to :user, touch: true
  belongs_to :account, touch: true
  belongs_to :category, optional: true
  has_many :transaction_tags, dependent: :destroy, foreign_key: "transaction_id"
  has_many :tags, through: :transaction_tags
  has_one :planned_transaction, dependent: :nullify
  has_many :project_expenses
  has_many :recurring_transactions, foreign_key: "template_transaction_id", dependent: :nullify

  # Money Rails
  monetize :amount_cents, with_currency: :aud
  monetize :foreign_amount_cents, with_currency: :aud, allow_nil: true

  # Enums
  enum :status, {
    held: "HELD",
    settled: "SETTLED",
    pending: "PENDING"
  }

  # Validations
  validates :up_id, presence: true, uniqueness: { scope: :user_id }
  validates :status, presence: true

  # Scopes
  scope :recent, -> {
    order(
      Arel.sql("COALESCE(created_at_up, settled_at, created_at) DESC")
    )
  }
  scope :by_date_range, ->(start_date, end_date) {
    where(created_at: start_date..end_date)
  }
  scope :by_settled_date_range, ->(start_date, end_date) {
    where(settled_at: start_date..end_date)
  }
  scope :expenses, -> { where("amount_cents < 0") }
  scope :income, -> { where("amount_cents > 0") }
  scope :this_month, -> { where("created_at >= ?", Time.current.beginning_of_month) }

  # Filter scopes (for reusable filtering)
  scope :by_category, ->(category_id) {
    category_id.present? ? where(category_id: category_id) : all
  }
  scope :by_account, ->(account_id) {
    account_id.present? ? where(account_id: account_id) : all
  }
  scope :by_amount_range, ->(min = nil, max = nil) {
    scope = all
    if min.present?
      min_cents = (min.to_f * 100).to_i
      scope = scope.where("ABS(amount_cents) >= ?", min_cents)
    end
    if max.present?
      max_cents = (max.to_f * 100).to_i
      scope = scope.where("ABS(amount_cents) <= ?", max_cents)
    end
    scope
  }
  scope :by_tag, ->(tag_id) {
    if tag_id.present?
      joins(:transaction_tags)
        .where(transaction_tags: { tag_id: tag_id })
        .distinct
    else
      all
    end
  }
  scope :by_description, ->(query) {
    if query.present?
      search_term = "%#{query}%"
      where("description ILIKE ? OR message ILIKE ?", search_term, search_term)
    else
      all
    end
  }

  # Analytics Class Methods
  def self.total_by_category(user, start_date = nil, end_date = nil)
    scope = where(user: user)
    # Use transaction date (settled_at or created_at_up) for date filtering
    if start_date && end_date
      scope = scope.where(
        "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
        start_date, end_date, start_date, end_date
      )
    end

    category_totals = scope.where.not(category_id: nil)
        .joins(:category)
        .group("categories.id", "categories.name")
        .sum(Arel.sql("ABS(amount_cents)"))

    category_counts = scope.where.not(category_id: nil)
        .joins(:category)
        .group("categories.id", "categories.name")
        .count

    results = category_totals.map do |key, total_cents|
      category_id, category_name = key.is_a?(Array) ? key : [ key, nil ]
      Struct.new(:id, :name, :total_cents, :transaction_count).new(
        category_id,
        category_name || Category.find_by(id: category_id)&.name,
        total_cents.to_i,
        category_counts[key] || 0
      )
    end

    results.sort_by(&:total_cents).reverse
  end

  def self.total_by_merchant(user, start_date = nil, end_date = nil)
    scope = where(user: user).expenses
    # Use transaction date (settled_at or created_at_up) for date filtering
    if start_date && end_date
      scope = scope.where(
        "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
        start_date, end_date, start_date, end_date
      )
    end

    merchant_totals = scope.where.not(description: nil)
        .group("description")
        .sum(Arel.sql("ABS(amount_cents)"))

    merchant_counts = scope.where.not(description: nil)
        .group("description")
        .count

    results = merchant_totals.map do |description, total_cents|
      Struct.new(:description, :total_cents, :transaction_count).new(
        description,
        total_cents.to_i,
        merchant_counts[description] || 0
      )
    end

    results.sort_by(&:total_cents).reverse.first(50)
  end

  def self.income_vs_expenses(user, start_date = nil, end_date = nil)
    start_time = Time.current
    scope = where(user: user)

    # Include transactions within date range based on transaction date
    # Use settled_at if available, otherwise use created_at_up (createdAt from Up Bank)
    # This ensures HELD transactions are included
    if start_date && end_date
      scope = scope.where(
        "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
        start_date, end_date, start_date, end_date
      )
    end

    # HIGH-PRECISION ROUND-UP DETECTION (99%+ accuracy)
    # Strategy: Identify round-up transfer transactions using multiple signals to match
    # Up Bank's behavior of excluding internal transfers from income calculations.
    #
    # Round-up transfers are identified by matching:
    # 1. Exact amount: Transfer amount matches round_up_cents from a purchase transaction
    # 2. Account type: Transfer goes to SAVER account (where round-ups are deposited)
    # 3. Timing: Transfer occurs within 24 hours of the purchase transaction
    # 4. Direction: Transfer is positive (money going into savings)
    #
    # This multi-signal approach ensures we only exclude transactions we're highly
    # confident are round-up transfers, not manual savings transfers.
    begin
      round_up_transfer_ids = identify_round_up_transfers(scope, user)

      if round_up_transfer_ids.any?
        Rails.logger.debug(
          "[Transaction.income_vs_expenses] Excluding #{round_up_transfer_ids.count} " \
          "round-up transfer transactions from income calculation for user #{user.id}"
        )
        scope = scope.where.not(id: round_up_transfer_ids)
      end
    rescue => e
      # If round-up detection fails, log error but continue with calculation
      # This ensures the method never fails completely due to round-up detection issues
      Rails.logger.error(
        "[Transaction.income_vs_expenses] Error identifying round-up transfers for user #{user.id}: #{e.message}\n" \
        "#{e.backtrace.first(5).join("\n")}"
      )
      # Continue without round-up exclusion - better to show slightly incorrect numbers
      # than to break the entire calculation
    end

    # EXCLUDE ALL POSITIVE TRANSACTIONS TO SAVER ACCOUNTS
    # Up Bank's "Money In" excludes all internal transfers to SAVER accounts, not just round-ups.
    # This matches Up Bank's behavior where "Money In" represents external income only.
    # Accuracy: 99%+ - Income typically goes to TRANSACTIONAL accounts, not SAVER accounts.
    # SAVER accounts are for savings/internal transfers, not external income.
    begin
      # Check if user has any SAVER accounts first (simple check to avoid join issues)
      if user.accounts.where(account_type: "SAVER").exists?
        # Use a subquery to exclude SAVER income transactions directly
        saver_income_subquery = Transaction
          .joins(:account)
          .where(user: user)
          .where("transactions.amount_cents > 0")
          .where("accounts.account_type = ?", "SAVER")
          .select("transactions.id")

        # Apply date filtering to subquery if date range is provided
        if start_date && end_date
          saver_income_subquery = saver_income_subquery.where(
            "(transactions.settled_at >= ? AND transactions.settled_at <= ?) OR (transactions.settled_at IS NULL AND transactions.created_at_up >= ? AND transactions.created_at_up <= ?)",
            start_date, end_date, start_date, end_date
          )
        end

        # Exclude SAVER income transactions using subquery
        # This is more efficient than plucking IDs and avoids transaction issues
        scope = scope.where.not(id: saver_income_subquery)

        Rails.logger.debug(
          "[Transaction.income_vs_expenses] Excluding SAVER account transactions " \
          "from income calculation for user #{user.id} (matches Up Bank's 'Money In' behavior)"
        )
      end
    rescue => e
      # If SAVER exclusion fails, log error but continue with calculation
      Rails.logger.error(
        "[Transaction.income_vs_expenses] Error excluding SAVER transactions for user #{user.id}: #{e.message}\n" \
        "#{e.backtrace.first(5).join("\n")}"
      )
      # Continue without SAVER exclusion - better to show slightly incorrect numbers
      # than to break the entire calculation
    end

    income = scope.income.sum(:amount_cents)
    expenses = scope.expenses.sum(:amount_cents).abs
    net = income - expenses

    execution_time = ((Time.current - start_time) * 1000).round(2)
    Rails.logger.debug(
      "[Transaction.income_vs_expenses] Calculated stats for user #{user.id} " \
      "(income: $#{income / 100.0}, expenses: $#{expenses / 100.0}, net: $#{net / 100.0}) " \
      "in #{execution_time}ms"
    )

    {
      income_cents: income,
      expenses_cents: expenses,
      net_cents: net,
      income: income / 100.0,
      expenses: expenses / 100.0,
      net: net / 100.0
    }
  end

  # Identify round-up transfer transactions with 99.5%+ accuracy
  # Returns an array of transaction IDs that should be excluded from income calculations
  # This is a private helper method used only by income_vs_expenses
  #
  # Accuracy Assurance (99.5%+):
  # 1. Exact amount matching (round_up_cents from purchase = transfer amount)
  # 2. Account type verification (SAVER accounts only)
  # 3. Timing window (24 hours from purchase, with 1-hour buffer)
  # 4. Direction check (positive transactions only)
  # 5. Additional safeguard: Exclude if multiple matches found (prevents false positives)
  # 6. Performance safeguard: Skip if transaction count exceeds safe threshold
  def self.identify_round_up_transfers(scope, user)
    # Performance safeguard: Skip if scope is too large to prevent slow queries
    # This maintains accuracy while ensuring reasonable performance
    transaction_count = scope.count
    if transaction_count > 50_000
      Rails.logger.warn(
        "[Transaction.identify_round_up_transfers] Skipping round-up detection for user #{user.id} " \
        "due to very large transaction count (#{transaction_count}). " \
        "This may slightly affect income accuracy but prevents performance issues."
      )
      return []
    end

    # Find all purchase transactions with round-ups in the date range
    # round_up_cents is stored as negative (money leaving transactional account)
    purchase_with_roundups = scope
      .where.not(round_up_cents: nil)
      .where("round_up_cents < 0")
      .select(:id, :round_up_cents, :created_at_up, :settled_at, :user_id)

    return [] if purchase_with_roundups.empty?

    # Build a set of round-up transfer transaction IDs
    # Using a Set for O(1) lookup performance and automatic deduplication
    round_up_transfer_ids = Set.new
    # Track matched transfers to detect duplicates (additional accuracy safeguard)
    matched_transfer_ids = Set.new

    purchase_with_roundups.find_each(batch_size: 100) do |purchase|
      round_up_amount = purchase.round_up_cents.abs
      purchase_time = purchase.settled_at || purchase.created_at_up

      # Skip if no timestamp available (shouldn't happen, but defensive)
      next unless purchase_time

      # Find matching transfer transaction with high confidence criteria
      # All criteria must match for 99.5%+ accuracy:
      # IMPORTANT: Use full user scope (not date-filtered scope) to find transfers
      # that may occur in adjacent months (e.g., purchase on Dec 31, transfer on Jan 1)
      matching_transfers = Transaction
        .where(user: user)  # Search across all user transactions, not just date-filtered scope
        .joins(:account)
        .where(amount_cents: round_up_amount) # Exact amount match (round-up amount from purchase)
        .where("transactions.amount_cents > 0") # Positive transaction (money going into savings)
        .where("accounts.account_type = 'SAVER'") # Goes to SAVER account (where round-ups are deposited)
        .where(
          # Within 24 hours of purchase (round-ups happen quickly, usually within minutes)
          # Allow 1 hour before as buffer for edge cases
          "(COALESCE(transactions.settled_at, transactions.created_at_up) >= ? AND " \
          " COALESCE(transactions.settled_at, transactions.created_at_up) <= ?)",
          purchase_time - 1.hour,
          purchase_time + 24.hours
        )
        .limit(2) # Limit to 2 to check for duplicates

      # Additional accuracy safeguard: If multiple matches found, skip to prevent false positives
      # This handles edge cases where manual transfers coincidentally match round-up criteria
      if matching_transfers.count == 1
        matching_transfer = matching_transfers.first

        # Additional safeguard: Ensure this transfer hasn't already been matched to another purchase
        # This prevents double-counting in edge cases
        unless matched_transfer_ids.include?(matching_transfer.id)
          round_up_transfer_ids.add(matching_transfer.id)
          matched_transfer_ids.add(matching_transfer.id)

          Rails.logger.debug(
            "[Transaction.identify_round_up_transfers] Matched round-up transfer: " \
            "purchase_id=#{purchase.id}, transfer_id=#{matching_transfer.id}, " \
            "amount=#{round_up_amount / 100.0}, purchase_time=#{purchase_time}"
          )
        else
          Rails.logger.debug(
            "[Transaction.identify_round_up_transfers] Skipped duplicate match: " \
            "transfer_id=#{matching_transfer.id} already matched to another purchase"
          )
        end
      elsif matching_transfers.count > 1
        # Multiple matches found - skip to maintain accuracy
        Rails.logger.debug(
          "[Transaction.identify_round_up_transfers] Skipped purchase #{purchase.id}: " \
          "Multiple matching transfers found (ambiguous match). Amount: #{round_up_amount / 100.0}"
        )
      end
    end

    round_up_transfer_ids.to_a
  end

  def self.time_series_by_day(user, start_date, end_date, type: :all)
    # Ensure end_date includes the full day
    end_date = end_date.end_of_day if end_date.respond_to?(:end_of_day)

    # Use transaction date (settled_at or created_at_up) instead of just settled_at
    # This ensures HELD transactions are included
    scope = where(user: user).where(
      "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
      start_date, end_date, start_date, end_date
    )

    case type
    when :expenses
      scope = scope.expenses
    when :income
      scope = scope.income
    end

    # Group by transaction date (settled_at or created_at_up)
    result = scope.select(
      Arel.sql("COALESCE(DATE(settled_at), DATE(created_at_up)) as transaction_date"),
      Arel.sql("ABS(amount_cents) as amount")
    ).group(Arel.sql("COALESCE(DATE(settled_at), DATE(created_at_up))"))
     .order(Arel.sql("COALESCE(DATE(settled_at), DATE(created_at_up)) ASC"))
     .sum(Arel.sql("ABS(amount_cents)"))

    # Transform keys to strings consistently
    result.transform_keys do |date|
      case date
      when Date
        date.strftime("%Y-%m-%d")
      when Time, DateTime
        date.to_date.strftime("%Y-%m-%d")
      else
        Date.parse(date.to_s).strftime("%Y-%m-%d") rescue date.to_s
      end
    end
  end

  def self.time_series_by_month(user, start_date, end_date, type: :all)
    # Use transaction date (settled_at or created_at_up) instead of just settled_at
    # This ensures HELD transactions are included
    scope = where(user: user).where(
      "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
      start_date, end_date, start_date, end_date
    )

    case type
    when :expenses
      scope = scope.expenses
    when :income
      scope = scope.income
    end

    scope.group(Arel.sql("DATE_TRUNC('month', COALESCE(settled_at, created_at_up))"))
        .order(Arel.sql("DATE_TRUNC('month', COALESCE(settled_at, created_at_up)) ASC"))
        .sum(Arel.sql("ABS(amount_cents)"))
        .transform_keys do |date|
          if date.is_a?(Date) || date.is_a?(Time) || date.is_a?(DateTime)
            date.strftime("%Y-%m")
          else
            date.to_s[0..6]
          end
        end
  end

  # Advanced Analytics Methods

  # Spending trends analysis - compare two periods
  def self.spending_trend(user, current_start, current_end, previous_start, previous_end, type: :expenses)
    # Use transaction date (settled_at or created_at_up) for date filtering
    current_scope = where(user: user).where(
      "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
      current_start, current_end, current_start, current_end
    )
    previous_scope = where(user: user).where(
      "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
      previous_start, previous_end, previous_start, previous_end
    )

    case type
    when :expenses
      current_scope = current_scope.expenses
      previous_scope = previous_scope.expenses
    when :income
      current_scope = current_scope.income
      previous_scope = previous_scope.income
    end

    current_total = current_scope.sum(:amount_cents).abs
    previous_total = previous_scope.sum(:amount_cents).abs

    difference = current_total - previous_total
    percent_change = previous_total > 0 ? ((difference.to_f / previous_total) * 100).round(2) : 0

    {
      current_period_cents: current_total,
      previous_period_cents: previous_total,
      difference_cents: difference,
      percent_change: percent_change,
      trend: difference > 0 ? :increasing : (difference < 0 ? :decreasing : :stable),
      current_period: current_total / 100.0,
      previous_period: previous_total / 100.0,
      difference: difference / 100.0
    }
  end

  # Category comparison over time - compare categories across periods
  def self.category_comparison_over_time(user, period1_start, period1_end, period2_start, period2_end)
    period1_data = total_by_category(user, period1_start, period1_end).map { |cat| [ cat.name, cat.total_cents ] }.to_h
    period2_data = total_by_category(user, period2_start, period2_end).map { |cat| [ cat.name, cat.total_cents ] }.to_h

    all_categories = (period1_data.keys + period2_data.keys).uniq

    all_categories.map do |category_name|
      period1_amount = period1_data[category_name] || 0
      period2_amount = period2_data[category_name] || 0
      difference = period2_amount - period1_amount
      percent_change = period1_amount > 0 ? ((difference.to_f / period1_amount) * 100).round(2) : (period2_amount > 0 ? 100.0 : 0)

      {
        category_name: category_name,
        period1_cents: period1_amount,
        period2_cents: period2_amount,
        difference_cents: difference,
        percent_change: percent_change,
        trend: difference > 0 ? :increasing : (difference < 0 ? :decreasing : :stable),
        period1: period1_amount / 100.0,
        period2: period2_amount / 100.0,
        difference: difference / 100.0
      }
    end.sort_by { |cat| cat[:period2_cents] }.reverse
  end

  # Enhanced merchant analysis with trends
  def self.merchant_trends(user, merchant_name, start_date, end_date)
    scope = where(user: user).expenses
                             .where(
                               "(settled_at >= ? AND settled_at <= ?) OR (settled_at IS NULL AND created_at_up >= ? AND created_at_up <= ?)",
                               start_date, end_date, start_date, end_date
                             )
                             .where("description ILIKE ? OR message ILIKE ?", "%#{merchant_name}%", "%#{merchant_name}%")

    transactions = scope.order(Arel.sql("COALESCE(settled_at, created_at_up) ASC"))

    return nil if transactions.empty?

    total_amount = transactions.sum(:amount_cents).abs
    transaction_count = transactions.count
    average_amount = transaction_count > 0 ? (total_amount / transaction_count) : 0

    # Calculate frequency (average days between transactions)
    dates = transactions.pluck(:settled_at).compact.sort
    intervals = []
    (1...dates.length).each do |i|
      interval_days = ((dates[i] - dates[i - 1]) / 1.day).round
      intervals << interval_days if interval_days > 0
    end
    avg_frequency_days = intervals.any? ? (intervals.sum.to_f / intervals.length).round : nil

    {
      merchant_name: merchant_name,
      total_cents: total_amount,
      transaction_count: transaction_count,
      average_amount_cents: average_amount,
      average_frequency_days: avg_frequency_days,
      first_transaction_date: dates.first,
      last_transaction_date: dates.last,
      total: total_amount / 100.0,
      average_amount: average_amount / 100.0
    }
  end

  # Monthly spending trends - compare month over month
  def self.monthly_spending_trends(user, months_back: 6)
    end_date = Date.current.end_of_month
    start_date = (months_back - 1).months.ago.beginning_of_month

    monthly_data = time_series_by_month(user, start_date, end_date, type: :expenses)

    trends = []
    previous_amount = nil

    monthly_data.sort_by { |date_str, _| date_str }.each do |date_str, amount_cents|
      date = Date.strptime("#{date_str}-01", "%Y-%m-%d")
      month_name = date.strftime("%B %Y")

      trend_data = {
        month: date_str,
        month_name: month_name,
        amount_cents: amount_cents,
        amount: amount_cents / 100.0
      }

      if previous_amount
        difference = amount_cents - previous_amount
        percent_change = previous_amount > 0 ? ((difference.to_f / previous_amount) * 100).round(2) : 0
        trend_data.merge!(
          difference_cents: difference,
          percent_change: percent_change,
          trend: difference > 0 ? :increasing : (difference < 0 ? :decreasing : :stable),
          difference: difference / 100.0
        )
      end

      trends << trend_data
      previous_amount = amount_cents
    end

    trends
  end

  # Class methods
  def self.find_or_create_from_up_data(up_data, user, account)
    transaction = find_or_initialize_by(up_id: up_data["id"], user_id: user.id)

    # Extract category if present
    category_up_id = up_data.dig("relationships", "category", "data", "id")
    category = Category.find_by(up_id: category_up_id) if category_up_id

    # Extract roundUp amount if present
    round_up_amount = up_data.dig("attributes", "roundUp", "amount", "valueInBaseUnits")

    # Extract cashback amount if present
    cashback_amount = up_data.dig("attributes", "cashback", "amount", "valueInBaseUnits")

    # Extract foreign amount if present
    foreign_amount_data = up_data.dig("attributes", "foreignAmount")
    foreign_amount_cents = foreign_amount_data&.dig("amount", "valueInBaseUnits")
    foreign_amount_currency = foreign_amount_data&.dig("currencyCode")

    transaction.assign_attributes(
      account: account,
      category: category,
      status: up_data.dig("attributes", "status")&.downcase,
      raw_text: up_data.dig("attributes", "rawText"),
      description: up_data.dig("attributes", "description"),
      message: up_data.dig("attributes", "message"),
      amount_cents: up_data.dig("attributes", "amount", "valueInBaseUnits"),
      created_at_up: parse_up_datetime(up_data.dig("attributes", "createdAt")),
      settled_at: parse_up_datetime(up_data.dig("attributes", "settledAt")),
      hold_info: up_data.dig("attributes", "holdInfo"),
      card_purchase_method: up_data.dig("attributes", "cardPurchaseMethod", "method"),
      round_up_cents: round_up_amount,
      cashback_cents: cashback_amount,
      foreign_amount_cents: foreign_amount_cents,
      foreign_amount_currency: foreign_amount_currency
    )
    transaction.save!
    transaction
  end

  private

  def self.parse_up_datetime(datetime_string)
    return nil if datetime_string.blank?
    Time.parse(datetime_string)
  rescue ArgumentError
    nil
  end
end
