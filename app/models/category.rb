class Category < ApplicationRecord
  has_many :transaction_categories, dependent: :destroy
  has_many :transactions, through: :transaction_categories
  has_many :budgets

  belongs_to :parent, class_name: "Category", foreign_key: "parent_id", primary_key: "up_id", optional: true
  has_many :children, class_name: "Category", foreign_key: "parent_id", primary_key: "up_id"

  validates :up_id, presence: true, uniqueness: true
  validates :name, presence: true

  # Diagnostic method to validate parent relationship
  def self.validate_parent_relationships
    Rails.logger.info "=== Category Parent Relationship Validation ==="
    
    # Check database column type
    column_info = Category.columns.find { |c| c.name == "parent_id" }
    Rails.logger.info "parent_id column type: #{column_info&.type}, sql_type: #{column_info&.sql_type}"
    
    # Check sample data
    categories_with_parents = Category.where.not(parent_id: nil).limit(5)
    Rails.logger.info "Categories with parents: #{categories_with_parents.count}"
    
    categories_with_parents.each do |cat|
      Rails.logger.info "  Category: #{cat.up_id} (#{cat.id}), parent_id value: #{cat.parent_id.inspect} (#{cat.parent_id.class})"
      
      # Try to access parent via association
      begin
        parent = cat.parent
        if parent
          Rails.logger.info "    ✓ Association works: parent = #{parent.up_id} (#{parent.id})"
        else
          Rails.logger.warn "    ✗ Association returned nil (parent_id: #{cat.parent_id})"
          
          # Try manual lookup
          manual_parent = Category.find_by(up_id: cat.parent_id)
          if manual_parent
            Rails.logger.info "    → Manual lookup found: #{manual_parent.up_id} (#{manual_parent.id})"
            Rails.logger.warn "    → Association mismatch: parent_id references up_id, but belongs_to expects id"
          else
            Rails.logger.error "    ✗ Manual lookup also failed - parent category doesn't exist"
          end
        end
      rescue => e
        Rails.logger.error "    ✗ Association error: #{e.class} - #{e.message}"
        Rails.logger.error "    → This confirms the association is broken"
      end
    end
    
    # Check if any categories reference non-existent parents
    all_parent_ids = Category.pluck(:parent_id).compact.uniq
    existing_up_ids = Category.pluck(:up_id)
    missing_parents = all_parent_ids - existing_up_ids
    
    if missing_parents.any?
      Rails.logger.warn "Categories referencing non-existent parents: #{missing_parents.inspect}"
    else
      Rails.logger.info "All parent_id values reference existing categories"
    end
    
    Rails.logger.info "=== End Validation ==="
  end
end

