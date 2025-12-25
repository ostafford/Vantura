class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :account
  has_many :transaction_categories, dependent: :destroy, foreign_key: "transaction_id"
  has_many :categories, through: :transaction_categories
  has_many :transaction_tags, dependent: :destroy
  has_many :tags, through: :transaction_tags

  validates :up_id, presence: true, uniqueness: { scope: :user_id }
  validates :status, inclusion: { in: %w[HELD SETTLED] }
  validates :amount, presence: true

  scope :settled, -> { where(status: 'SETTLED') }
  scope :held, -> { where(status: 'HELD') }
  scope :recent, -> { where('settled_at >= ?', 12.months.ago) }
  scope :by_date_range, ->(start_date, end_date) {
    where(settled_at: start_date..end_date)
  }
  scope :by_category, ->(category_id) {
    joins(:categories).where(categories: { id: category_id })
  }
  scope :search, ->(query) {
    return all if query.blank?
    
    query = query.to_s.strip
    return all if query.empty?
    
    # Search in description, raw_text, category names, account display names
    # Also support amount range queries like ">100" or "<50"
    amount_match = query.match(/\A([<>]?)\s*\$?(\d+(?:\.\d+)?)\z/)
    
    if amount_match
      operator = amount_match[1]
      amount = amount_match[2].to_f
      
      case operator
      when '>'
        where('ABS(amount) > ?', amount * 100) # Convert to cents
      when '<'
        where('ABS(amount) < ?', amount * 100)
      else
        # Exact amount match (within 1 cent tolerance)
        where('ABS(amount) BETWEEN ? AND ?', (amount * 100 - 1), (amount * 100 + 1))
      end
    else
      # Text search
      search_term = "%#{query}%"
      left_joins(:categories, :account)
        .where(
          "transactions.description ILIKE ? OR transactions.raw_text ILIKE ? OR categories.name ILIKE ? OR accounts.display_name ILIKE ? OR accounts.account_type ILIKE ?",
          search_term, search_term, search_term, search_term, search_term
        )
        .distinct
    end
  }

  def debit?
    amount.negative?
  end

  def credit?
    amount.positive?
  end

  def amount_abs
    amount.abs
  end
end

