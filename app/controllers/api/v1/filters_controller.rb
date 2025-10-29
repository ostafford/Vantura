# API controller for filters
class Api::V1::FiltersController < Api::V1::BaseController
  before_action :set_filter, only: [:show, :update, :destroy]

  # GET /api/v1/filters
  def index
    filters = Current.user.filters.recent
    render_success(filters.map(&:attributes))
  end

  # GET /api/v1/filters/:id
  def show
    render_success(@filter.attributes)
  end

  # POST /api/v1/filters
  def create
    @filter = Current.user.filters.build(filter_params)

    if @filter.save
      render_success(@filter.attributes, status: :created)
    else
      render_error(
        code: 'validation_error',
        message: 'Filter validation failed',
        details: @filter.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end

  # PATCH /api/v1/filters/:id
  def update
    if @filter.update(filter_params)
      render_success(@filter.attributes)
    else
      render_error(
        code: 'validation_error',
        message: 'Filter validation failed',
        details: @filter.errors.as_json,
        status: :unprocessable_entity
      )
    end
  end

  # DELETE /api/v1/filters/:id
  def destroy
    @filter.destroy
    render_success({ message: 'Filter deleted successfully' })
  end

  private

  def set_filter
    @filter = Current.user.filters.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      code: 'not_found',
      message: 'Filter not found',
      status: :not_found
    )
  end

  def filter_params
    params.require(:filter).permit(:name, filter_types: [], filter_params: {}, date_range: {})
  end
end

