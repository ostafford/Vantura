class ApplicationController < ActionController::Base
  # Pagy 4.3: Use Pagy::Method instead of Pagy::Backend
  include Pagy::Method

  # Pundit for authorization
  # Reference: https://github.com/varvet/pundit
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Handle Pundit authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = I18n.t("flash.not_authorized")
    
    # Try to redirect to the resource's index page if available
    # This provides better UX than always going to root
    fallback = case controller_name
               when "projects", "project_expenses"
                 projects_path
               when "transactions"
                 transactions_path
               when "goals"
                 goals_path
               when "planned_transactions"
                 planned_transactions_path
               else
                 root_path
               end
    
    redirect_back(fallback_location: fallback)
  end
end
