class ApplicationController < ActionController::Base
  # Pagy 4.3: Use Pagy::Method instead of Pagy::Backend
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
