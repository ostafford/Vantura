# Base controller for all API v1 endpoints
# Provides standardized response formatting and authentication
class Api::V1::BaseController < ApplicationController
  include AccountLoadable

  # Skip CSRF token verification for API endpoints (handled via session cookies)
  # API client will include CSRF token in headers from meta tag
  skip_before_action :verify_authenticity_token

  # Force JSON format for all API requests
  before_action :set_json_format
  before_action :set_api_error_context

  # Standard success response
  # @param data [Object] The response data (model, array, hash)
  # @param meta [Hash] Optional metadata (pagination, timestamp, version)
  # @param status [Symbol] HTTP status code (default: :ok)
  def render_success(data, meta: nil, status: :ok)
    response_data = {
      data: data,
      meta: build_meta(meta)
    }
    render json: response_data, status: status
  end

  # Standard error response
  # @param code [String] Error code (e.g., 'validation_error', 'not_found')
  # @param message [String] Human-readable error message
  # @param details [Hash] Optional error details (validation errors, etc.)
  # @param status [Symbol] HTTP status code (default: :unprocessable_entity)
  def render_error(code:, message:, details: nil, status: :unprocessable_entity)
    render json: {
      error: {
        code: code,
        message: message,
        details: details
      }
    }, status: status
  end

  # Pagination helper
  # @param collection [ActiveRecord::Relation] The collection to paginate (will call count on it)
  # @param page [Integer] Current page number
  # @param per_page [Integer] Items per page
  # @param total [Integer] Optional total count (avoids extra COUNT query if already calculated)
  def pagination_meta(collection, page: 1, per_page: 20, total: nil)
    total ||= collection.count
    {
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

  private

  def set_json_format
    request.format = :json
  end

  def set_api_error_context
    # Add API-specific context to error reporting
    Rails.error.set_context(
      api_version: 'v1',
      endpoint: "#{request.method} #{request.path}"
    )
  end

  def build_meta(custom_meta = nil)
    base_meta = {
      timestamp: Time.current.iso8601,
      version: 'v1'
    }
    custom_meta ? base_meta.merge(custom_meta) : base_meta
  end

  # Override request_authentication to return JSON error instead of redirect
  def request_authentication
    render_error(
      code: 'unauthorized',
      message: 'Authentication required',
      status: :unauthorized
    )
  end

  # Override load_account to return JSON error instead of redirect
  def load_account
    @account = Current.user.accounts.order(:created_at).last

    unless @account
      render_error(
        code: 'account_not_found',
        message: 'Please configure your Up Bank token first.',
        status: :not_found
      )
      return false
    end

    true
  end
end

