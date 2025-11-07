class RecurringTransaction < ApplicationRecord
  # Associations
  belongs_to :account
  belongs_to :template_transaction, class_name: "Transaction", optional: true
  has_many :generated_transactions, class_name: "Transaction", foreign_key: "recurring_transaction_id", dependent: :destroy

  # Validations
  validates :description, presence: true
  validates :amount, presence: true, numericality: true
  validates :frequency, presence: true
  validates :next_occurrence_date, presence: true
  validates :transaction_type, presence: true
  validates :is_active, inclusion: { in: [ true, false ] }
  validates :date_tolerance_days, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 14 }
  validates :tolerance_type, presence: true, inclusion: { in: %w[fixed percentage] }
  with_options if: -> { tolerance_type == "percentage" } do
    validates :tolerance_percentage, presence: true
    validates :tolerance_percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  end
  validate :recurring_category_matches_transaction_type

  # Enums
  enum :frequency, {
    weekly: "weekly",
    fortnightly: "fortnightly",
    monthly: "monthly",
    quarterly: "quarterly",
    yearly: "yearly"
  }, prefix: true

  enum :transaction_type, {
    income: "income",
    expense: "expense"
  }, prefix: true

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :income_transactions, -> { where(transaction_type: "income") }
  scope :expense_transactions, -> { where(transaction_type: "expense") }
  scope :due_soon, ->(days = 7) { where("next_occurrence_date <= ?", Date.today + days.days) }

  # Methods
  def calculate_next_occurrence(from_date = next_occurrence_date)
    case frequency
    when "weekly"
      from_date + 1.week
    when "fortnightly"
      from_date + 2.weeks
    when "monthly"
      from_date + 1.month
    when "quarterly"
      from_date + 3.months
    when "yearly"
      from_date + 1.year
    end
  end

  def matches_transaction?(transaction, category: nil)
    return false unless merchant_pattern.present?

    # Check if merchant/description matches the pattern (exact or fuzzy)
    description_match = exact_match?(transaction.description) || fuzzy_match?(transaction.description)

    # Check if amount is within tolerance (fixed or percentage)
    amount_match = amount_within_tolerance?(transaction.amount)

    # Category matching is optional - increases confidence but not required
    # Merchant pattern is primary matching criteria
    _category_match = category.present? && self.category.present? && category == self.category

    description_match && amount_match
  end

  # Check for exact substring match (case insensitive)
  def exact_match?(description)
    return false if merchant_pattern.blank? || description.blank?
    description.downcase.include?(merchant_pattern.downcase)
  end

  # Check for fuzzy match using Levenshtein distance
  # Allows 1-2 character differences for typos
  def fuzzy_match?(description)
    return false if merchant_pattern.blank? || description.blank?

    pattern_words = merchant_pattern.downcase.split
    desc_words = description.downcase.split

    # Try to find a word in description that's similar to pattern
    pattern_words.any? do |pattern_word|
      desc_words.any? do |desc_word|
        distance = levenshtein_distance(pattern_word, desc_word)
        # Allow up to 2 character differences, or 20% of length (whichever is smaller)
        max_distance = [ 2, (pattern_word.length * 0.2).ceil ].min
        distance <= max_distance
      end
    end
  end

  # Calculate Levenshtein distance between two strings
  def levenshtein_distance(str1, str2)
    return str2.length if str1.empty?
    return str1.length if str2.empty?

    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1, 0) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      # deletion
          matrix[i][j - 1] + 1,      # insertion
          matrix[i - 1][j - 1] + cost # substitution
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end

  # Check if amount is within tolerance (fixed or percentage)
  def amount_within_tolerance?(transaction_amount)
    return false if amount.nil? || transaction_amount.nil?

    amount_diff = (transaction_amount.abs - amount.abs).abs

    if tolerance_type == "percentage"
      return false unless tolerance_percentage.present?
      tolerance_amount = amount.abs * (tolerance_percentage / 100.0)
      amount_diff <= tolerance_amount
    else
      tolerance = amount_tolerance || 5.0
      amount_diff <= tolerance
    end
  end

  # Get display name for recurring category
  def recurring_category_name
    return nil unless recurring_category.present?

    # Check if it's a predefined category (case-insensitive)
    predefined = RecurringCategory.predefined_for_type(transaction_type)
    return recurring_category.humanize if predefined.include?(recurring_category.downcase)

    # Check if it's a custom category (case-insensitive)
    custom_category = account.recurring_categories.find_by(
      "LOWER(name) = ? AND transaction_type = ?",
      recurring_category.downcase,
      transaction_type
    )
    return custom_category.name if custom_category

    # Fallback to the stored value
    recurring_category.humanize
  end

  # Get available categories for this transaction type
  def available_categories
    predefined = RecurringCategory.predefined_for_type(transaction_type)
    custom = account.recurring_categories.for_transaction_type(transaction_type).pluck(:name)
    (predefined + custom).uniq.sort_by(&:downcase)
  end

  private

  def recurring_category_matches_transaction_type
    return unless recurring_category.present?

    # Check if it's a predefined category for this transaction type
    predefined = RecurringCategory.predefined_for_type(transaction_type)
    if predefined.include?(recurring_category.downcase)
      return # Valid predefined category for this transaction type
    end

    # Check if it's a predefined category for the other transaction type (not allowed)
    other_type = transaction_type == "income" ? "expense" : "income"
    other_predefined = RecurringCategory.predefined_for_type(other_type)
    if other_predefined.include?(recurring_category.downcase)
      errors.add(:recurring_category, "must be a valid category for #{transaction_type} transactions")
      return
    end

    # Check if it's a custom category for this account and transaction type (case-insensitive)
    custom_category = account.recurring_categories.find_by(
      "LOWER(name) = ? AND transaction_type = ?",
      recurring_category.downcase,
      transaction_type
    )

    unless custom_category
      errors.add(:recurring_category, "must be a valid category for #{transaction_type} transactions")
    end
  end

  # Extract merchant pattern from transaction description
  # Removes common noise like numbers and reference codes
  # @param description [String] The transaction description
  # @return [String] Extracted merchant pattern (first 1-2 significant words)
  def self.extract_merchant_pattern(description)
    return "" if description.blank?

    # Remove common patterns like numbers, dates, reference codes
    pattern = description.gsub(/\d{4,}/, "") # Remove long numbers (e.g., transaction IDs)
                        .gsub(/\s+\d+$/, "")  # Remove trailing numbers
                        .strip

    # Take the first significant word(s) as the pattern
    words = pattern.split
    words.first(2).join(" ") # Use first 1-2 words as pattern
  end
end
