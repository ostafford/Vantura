class Filter < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :filter_types, presence: true

  # PostgreSQL jsonb columns handle JSON automatically - no serialization needed
  # filter_params, filter_types, and date_range are jsonb columns

  # Filter types
  FILTER_TYPES = %w[category merchant status recurring_transactions].freeze

  # Validate all filter types
  validate :validate_filter_types
  validate :validate_filter_params

  # Scopes
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :set_default_filter_params
  before_validation :normalize_filter_types

  # Helper methods
  def display_name
    name.humanize
  end

  def filter_description
    descriptions = []

    filter_types.each do |type|
      case type
      when "category"
        if filter_params["categories"]&.any?
          descriptions << "Categories: #{filter_params['categories'].join(', ')}"
        else
          descriptions << "Categories: All"
        end
      when "merchant"
        if filter_params["merchants"]&.any?
          descriptions << "Merchants: #{filter_params['merchants'].join(', ')}"
        else
          descriptions << "Merchants: All"
        end
      when "status"
        if filter_params["statuses"]&.any?
          descriptions << "Status: #{filter_params['statuses'].join(', ')}"
        else
          descriptions << "Status: All"
        end
      when "recurring_transactions"
        case filter_params["recurring_transactions"]
        when "true"
          descriptions << "From Recurring Only"
        when "false"
          descriptions << "Non-Recurring Only"
        when "both"
          descriptions << "Both Recurring and Non-Recurring"
        else
          descriptions << "Recurring: All"
        end
      end
    end

    descriptions.join(" • ")
  end

  private

  def set_default_filter_params
    self.filter_params ||= {}
    self.filter_types ||= []

    # Ensure filter_params is a hash
    if filter_params.present? && !filter_params.is_a?(Hash)
      self.filter_params = {}
    end
  end

  def normalize_filter_types
    # Ensure filter_types is an array and remove duplicates
    self.filter_types = Array(filter_types).compact.uniq if filter_types.present?
  end

  def validate_filter_types
    unless filter_types.is_a?(Array) && filter_types.all? { |type| FILTER_TYPES.include?(type) }
      errors.add(:filter_types, "must be an array of valid filter types")
    end
  end

  def validate_filter_params
    return unless filter_types.is_a?(Array)

    # Ensure filter_params is a hash (can be empty)
    errors.add(:filter_params, "must be present") if filter_params.nil?
    nil unless filter_params.is_a?(Hash)

    # Don't require parameters for each filter type - make them optional
    # This allows users to add filter types incrementally and select parameters later
    # If no parameters are selected for a type, that type just won't filter (shows all)
  end
end
