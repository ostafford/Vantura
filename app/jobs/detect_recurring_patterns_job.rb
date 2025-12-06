class DetectRecurringPatternsJob < ApplicationJob
  queue_as :default

  # Retry strategy for transient errors
  retry_on ActiveRecord::StatementInvalid, wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

  # Minimum number of occurrences to consider it a recurring pattern
  MIN_OCCURRENCES = 3

  # Look back period for analysis (default: 6 months)
  DEFAULT_LOOKBACK_MONTHS = 6

  def perform(user_id = nil)
    users = user_id ? User.where(id: user_id) : User.all

    users.find_each do |user|
      Rails.logger.info "Detecting recurring patterns for user #{user.id}"
      detect_patterns_for_user(user)
    end
  end

  private

  def detect_patterns_for_user(user)
    # Analyze transactions from the past 6 months
    start_date = DEFAULT_LOOKBACK_MONTHS.months.ago
    end_date = Date.current

    # Get all settled transactions in the period
    transactions = user.transactions
                      .settled
                      .where.not(settled_at: nil)
                      .where("settled_at >= ?", start_date)
                      .where("settled_at <= ?", end_date)
                      .order(:settled_at)

    # Group transactions by potential pattern keys
    pattern_groups = group_transactions_by_pattern(transactions)

    # Analyze each group for recurring patterns
    pattern_groups.each do |pattern_key, group_transactions|
      next if group_transactions.size < MIN_OCCURRENCES

      frequency = detect_frequency(group_transactions)
      next unless frequency

      # Create or update recurring transaction
      create_or_update_recurring_transaction(user, pattern_key, group_transactions, frequency)
    end
  end

  # Group transactions by similar merchant/description and amount (within tolerance)
  def group_transactions_by_pattern(transactions)
    groups = {}

    transactions.each do |transaction|
      # Create a pattern key based on merchant/description
      merchant_key = normalize_merchant(transaction.description || transaction.message)
      next if merchant_key.blank?

      # Group by account and merchant, with amount rounded to $5 buckets
      amount_cents = transaction.amount_cents.abs
      # Round to nearest $5 bucket (500 cents) for consistent grouping
      amount_bucket = ((amount_cents / 500.0).round * 500).to_i
      pattern_key = "#{transaction.account_id}|#{merchant_key}|#{amount_bucket}"

      groups[pattern_key] ||= []
      groups[pattern_key] << transaction
    end

    groups
  end

  # Normalize merchant name for pattern matching
  def normalize_merchant(merchant_string)
    return nil if merchant_string.blank?

    # Remove common prefixes/suffixes and normalize
    normalized = merchant_string.strip
                                  .gsub(/\s+/, " ")
                                  .upcase
                                  .gsub(/^(WWW\.|HTTPS?:\/\/)/, "") # Remove URLs
                                  .gsub(/\.(COM|NET|ORG|AU)\b/, "") # Remove domain extensions
                                  .gsub(/\s+\d{4}$/, "") # Remove trailing year/numbers
                                  .strip

    # Extract the core merchant name by removing common suffixes
    # Remove common transaction words like SUBSCRIPTION, PAYMENT, etc.
    normalized = normalized.gsub(/\s+(SUBSCRIPTION|PAYMENT|PAY|CHARGE|DEBIT|AUTHORISATION|AUTHORIZATION)$/i, "")

    # Take first significant words (max 2 words for pattern matching to catch core merchant name)
    words = normalized.split(/\s+/).reject { |w| w.length < 2 }

    # Get meaningful words (at least 3 chars) and take first 2 for core merchant name
    meaningful_words = words.select { |w| w.length >= 3 }
    result = meaningful_words.first(2).join(" ")

    # Return the result, or the original normalized string if empty
    result.present? ? result : normalized.split(/\s+/).first(2).join(" ")
  end

  # Detect the frequency pattern from transaction dates
  def detect_frequency(transactions)
    return nil if transactions.size < MIN_OCCURRENCES

    # Sort by date
    sorted = transactions.sort_by(&:settled_at)
    dates = sorted.map { |t| t.settled_at.to_date }

    # Calculate intervals between consecutive transactions
    intervals = []
    (1...dates.size).each do |i|
      interval_days = (dates[i] - dates[i - 1]).to_i
      intervals << interval_days if interval_days > 0
    end

    return nil if intervals.empty?

    # Find the most common interval (within tolerance)
    interval_counts = intervals.group_by { |days| normalize_interval(days) }
                               .transform_values(&:count)
    most_common_interval = interval_counts.max_by { |_interval, count| count }

    return nil unless most_common_interval

    interval_days, occurrence_count = most_common_interval
    return nil if occurrence_count < (intervals.size * 0.6) # At least 60% match

    interval_to_frequency(interval_days)
  end

  # Normalize interval to standard buckets (weekly, monthly, etc.)
  def normalize_interval(days)
    case days
    when 1..3
      1 # Daily-ish
    when 4..10
      7 # Weekly
    when 11..18
      14 # Bi-weekly
    when 19..35
      30 # Monthly
    when 36..60
      45 # Bi-monthly
    when 61..95
      90 # Quarterly
    when 270..370
      365 # Yearly
    else
      days # Keep exact if not matching standard intervals
    end
  end

  # Convert interval days to frequency string
  def interval_to_frequency(interval_days)
    case interval_days
    when 1
      "daily"
    when 7
      "weekly"
    when 14
      "weekly" # Bi-weekly can be treated as weekly with filtering
    when 30, 28, 29, 31
      "monthly"
    when 45
      "monthly" # Bi-monthly can be treated as monthly
    when 90
      "monthly" # Quarterly can be treated as monthly
    when 365, 366
      "yearly"
    else
      nil # Unknown pattern
    end
  end

  # Create or update a recurring transaction record
  def create_or_update_recurring_transaction(user, pattern_key, transactions, frequency)
    # Get representative transaction for the pattern
    representative = transactions.sort_by(&:settled_at).last
    account = representative.account

    # Extract account_id, merchant pattern and amount
    account_id, merchant_key, amount_bucket = pattern_key.split("|")
    average_amount_cents = transactions.map { |t| t.amount_cents.abs }.sum / transactions.size
    average_amount = (average_amount_cents / 100.0).round(2)

    # Determine transaction type
    transaction_type = transactions.first.amount_cents < 0 ? "expense" : "income"

    # Calculate next occurrence date
    last_date = transactions.max_by(&:settled_at).settled_at.to_date
    next_occurrence = calculate_next_occurrence(last_date, frequency)

    # Find existing recurring transaction for this pattern
    # Try exact match first
    existing = RecurringTransaction.find_by(
      account: account,
      merchant_pattern: merchant_key,
      transaction_type: transaction_type,
      is_active: true
    )

    # If no exact match, try fuzzy match on merchant pattern
    unless existing
      existing = RecurringTransaction.active
                                      .where(account: account, transaction_type: transaction_type)
                                      .find do |rt|
        rt.merchant_pattern.present? && merchant_key.present? &&
          (rt.merchant_pattern.upcase == merchant_key.upcase ||
           rt.merchant_pattern.upcase.include?(merchant_key.split.first.upcase) ||
           merchant_key.upcase.include?(rt.merchant_pattern.split.first.upcase))
      end
    end

    if existing
      # Update existing recurring transaction
      update_recurring_transaction(existing, average_amount, frequency, next_occurrence, representative)
    else
      # Create new recurring transaction
      create_recurring_transaction(user, account, merchant_key, average_amount, frequency, next_occurrence, transaction_type, representative)
    end
  end

  def update_recurring_transaction(recurring, amount, frequency, next_occurrence, representative)
    recurring.update!(
      amount: amount * (recurring.transaction_type == "expense" ? -1 : 1),
      frequency: frequency,
      next_occurrence_date: next_occurrence,
      template_transaction: representative,
      category: representative.category&.name,
      description: representative.description || representative.message
    )

    Rails.logger.info "Updated recurring transaction #{recurring.id} - #{recurring.description} (#{frequency})"
  end

  def create_recurring_transaction(user, account, merchant_pattern, amount, frequency, next_occurrence, transaction_type, representative)
    recurring = RecurringTransaction.create!(
      account: account,
      merchant_pattern: merchant_pattern,
      amount: amount * (transaction_type == "expense" ? -1 : 1),
      frequency: frequency,
      next_occurrence_date: next_occurrence,
      transaction_type: transaction_type,
      description: representative.description || representative.message,
      category: representative.category&.name,
      template_transaction: representative,
      is_active: true,
      amount_tolerance: 5.0 # $5 tolerance for pattern matching
    )

    Rails.logger.info "Created recurring transaction #{recurring.id} - #{recurring.description} (#{frequency})"
  rescue => e
    Rails.logger.error "Failed to create recurring transaction: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def calculate_next_occurrence(last_date, frequency)
    next_date = case frequency
    when "daily"
      last_date + 1.day
    when "weekly"
      last_date + 1.week
    when "monthly"
      last_date + 1.month
    when "yearly"
      last_date + 1.year
    else
      last_date + 1.month # Default fallback
    end

    # Ensure next occurrence is at least tomorrow if it's today or in the past
    next_date = Date.current + 1.day if next_date <= Date.current
    next_date
  end
end
