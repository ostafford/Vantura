class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Set global error context for all requests
  before_action :set_error_context

  # PWA offline page - skip authentication and layout
  allow_unauthenticated_access only: [ :offline ]

  def offline
    render "offline", layout: false
  end

  private

  def set_error_context
    # Set context that will be included with all errors reported from this request
    Rails.error.set_context(
      request_id: request.request_id,
      user_id: Current.session&.user&.id,
      user_email: Current.session&.user&.email_address,
      url: request.url,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
  end
end
