# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index ]

  def index
    Rails.logger.info "=== HomeController#index ==="
    Rails.logger.info "user_signed_in?: #{user_signed_in?.inspect}"
    Rails.logger.info "current_user: #{current_user&.id.inspect}"
    Rails.logger.info "authenticated_root_path: #{authenticated_root_path.inspect}"
    Rails.logger.info "request.path: #{request.path.inspect}"
    Rails.logger.info "request.fullpath: #{request.fullpath.inspect}"

    if user_signed_in?
      target_path = dashboard_path
      Rails.logger.info "Redirecting authenticated user to: #{target_path.inspect}"
      redirect_to target_path
    else
      Rails.logger.info "Rendering home page for unauthenticated user"
    end
  end
end
