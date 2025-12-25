module UpApi
  class CategoriesSync
    def initialize(personal_access_token = nil)
      # Categories are global, but we need a token to fetch them
      # If no token provided, we'll need to get it from somewhere else
      # For now, require it to be passed
      @client = Client.new(personal_access_token) if personal_access_token
    end

    def sync(personal_access_token)
      @client = Client.new(personal_access_token) unless @client

      Rails.logger.info "Starting categories sync"

      response = @client.categories
      categories_data = response["data"] || []

      # First pass: sync all categories (parent and child)
      categories_data.each do |category_data|
        sync_category(category_data)
      end

      Rails.logger.info "Categories sync complete: #{categories_data.size} categories"
    rescue UpApi::AuthenticationError => e
      Rails.logger.error "Authentication failed during categories sync: #{e.message}"
      raise
    rescue UpApi::ApiError => e
      Rails.logger.error "API error during categories sync: #{e.message}"
      raise
    end

    private

    def sync_category(category_data)
      category = Category.find_or_initialize_by(up_id: category_data["id"])

      attributes = category_data["attributes"]
      relationships = category_data["relationships"]

      # Get parent category up_id if it exists
      parent_up_id = relationships.dig("parent", "data", "id")

      Rails.logger.debug "Syncing category: #{category_data['id']}, parent_up_id: #{parent_up_id.inspect} (#{parent_up_id.class})"

      category.assign_attributes(
        name: attributes["name"],
        parent_id: parent_up_id
      )

      # Log what we're about to save
      Rails.logger.debug "  Before save - parent_id: #{category.parent_id.inspect} (#{category.parent_id.class})"
      Rails.logger.debug "  Category id: #{category.id.inspect}, up_id: #{category.up_id.inspect}"

      category.save!

      # After save, try to access parent via association
      if category.parent_id.present?
        begin
          parent = category.parent
          if parent
            Rails.logger.debug "  ✓ After save - parent association works: #{parent.up_id} (#{parent.id})"
          else
            Rails.logger.warn "  ✗ After save - parent association returned nil for parent_id: #{category.parent_id}"
            # Try manual lookup
            manual_parent = Category.find_by(up_id: category.parent_id)
            if manual_parent
              Rails.logger.warn "  → Manual lookup found parent: #{manual_parent.up_id} (#{manual_parent.id})"
              Rails.logger.warn "  → ASSOCIATION MISMATCH: parent_id stores up_id string, but belongs_to expects integer id"
            end
          end
        rescue => e
          Rails.logger.error "  ✗ After save - parent association error: #{e.class} - #{e.message}"
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save category #{category_data['id']}: #{e.message}"
      Rails.logger.error "  parent_id value: #{category.parent_id.inspect}"
      raise
    end
  end
end

