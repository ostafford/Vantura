require_relative "../../lib/up_api/errors"

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Require authentication for all actions (except those that skip it)
  before_action :authenticate_user!

  # Error handling for Up API errors
  rescue_from UpApi::AuthenticationError, with: :handle_authentication_error
  rescue_from UpApi::RateLimitError, with: :handle_rate_limit_error
  rescue_from UpApi::ApiError, with: :handle_api_error

  private

  def handle_authentication_error(exception)
    Rails.logger.error "Up API Authentication Error: #{exception.message}"
    flash[:alert] = "Your Up Bank token is invalid. Please update it in settings."
    redirect_to settings_path
  end

  def handle_rate_limit_error(exception)
    Rails.logger.warn "Up API Rate Limit Error: #{exception.message}"
    flash[:alert] = "Rate limit exceeded. Please try again later."
    redirect_back(fallback_location: root_path)
  end

  def handle_api_error(exception)
    Rails.logger.error "Up API Error: #{exception.message}"
    flash[:alert] = "An error occurred while fetching data. Please try again."
    redirect_back(fallback_location: root_path)
  end
end
