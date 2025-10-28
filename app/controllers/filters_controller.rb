class FiltersController < ApplicationController
  before_action :set_filter, only: [ :show, :edit, :update, :destroy ]

  def index
    @filters = Current.user.filters.recent
  end

  def show
  end

  def new
    @filter = Current.user.filters.build
  end

  def create
    @filter = Current.user.filters.build(filter_params)

    # Debug logging
    Rails.logger.debug "Filter params: #{filter_params.inspect}"
    Rails.logger.debug "Filter valid: #{@filter.valid?}"
    Rails.logger.debug "Filter errors: #{@filter.errors.full_messages}" unless @filter.valid?

    if @filter.save
      respond_to do |format|
        format.html { redirect_to analysis_path, notice: "Filter created successfully!" }
        format.json { render json: { success: true, filter: @filter } }
      end
    else
      respond_to do |format|
        format.html { redirect_to analysis_path, alert: "Error creating filter: #{@filter.errors.full_messages.join(', ')}" }
        format.json { render json: { success: false, error: @filter.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    # Debug logging
    Rails.logger.debug "Filter params: #{filter_params.inspect}"
    Rails.logger.debug "Filter valid: #{@filter.valid?}"
    Rails.logger.debug "Filter errors: #{@filter.errors.full_messages}" unless @filter.valid?

    if @filter.update(filter_params)
      respond_to do |format|
        format.html { redirect_to analysis_path, notice: "Filter updated successfully!" }
        format.json { render json: { success: true, filter: @filter } }
      end
    else
      respond_to do |format|
        format.html { redirect_to analysis_path, alert: "Error updating filter: #{@filter.errors.full_messages.join(', ')}" }
        format.json { render json: { success: false, error: @filter.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @filter.destroy
    redirect_to analysis_path, notice: "Filter deleted successfully!"
  end

  private

  def set_filter
    @filter = Current.user.filters.find(params[:id])
  end

  # Strong parameters for Filter model
  # Permits:
  # - name: String (required) - The filter name
  # - filter_types: Array of strings (required) - Valid types: category, merchant, status, recurring_transactions
  # - filter_params: Hash (optional) - Filter-specific parameters (e.g., categories, merchants, statuses)
  # - date_range: Hash (optional) - Date range with start_date and end_date
  def filter_params
    params.require(:filter).permit(:name, filter_types: [], filter_params: {}, date_range: {})
  end
end
