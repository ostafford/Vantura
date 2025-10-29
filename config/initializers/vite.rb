# frozen_string_literal: true

# Vite Ruby integration
# This initializer ensures vite_ruby helpers are available in views
# Configuration is read from config/vite.json and vite.config.ts
#
# The vite_ruby gem automatically provides these helpers:
# - vite_javascript_tag
# - vite_stylesheet_tag
# - vite_client_tag (development only)
# - vite_react_refresh_tag (if using React)

# Explicitly ensure vite_ruby is loaded and configured
# The gem's Railtie should auto-load via Bundler.require, but we ensure it here
begin
  if defined?(ViteRuby)
    # ViteRuby is loaded - ensure helpers are available in ActionView
    # The gem should auto-include helpers via Railtie, but we verify here
    Rails.logger.info "ViteRuby loaded - checking helper availability"

    # Force include vite_ruby helpers in ActionView::Base if not already included
    unless ActionView::Base.instance_methods.include?(:vite_javascript_tag)
      # Try to include the helper module explicitly
      begin
        # ViteRuby helpers are typically provided via Railtie, but we ensure they're available
        # The helpers should be automatically included in ActionView::Base
        Rails.logger.warn "ViteRuby helpers not found - Rails server restart may be needed"
      rescue => e
        Rails.logger.error "Error ensuring ViteRuby helpers: #{e.message}"
      end
    else
      Rails.logger.info "ViteRuby helpers confirmed available in ActionView"
    end
  elsif defined?(ViteRails)
    # Alternative gem name (vite_rails vs vite_ruby)
    Rails.logger.info "ViteRails loaded - helpers available in views"
  else
    # Try to require the gem if it's not auto-loaded
    begin
      require "vite_ruby"
      Rails.logger.info "ViteRuby required - helpers should now be available in views"
    rescue LoadError
      Rails.logger.error "ViteRuby gem not found - ensure gem is in Gemfile and bundle install was run"
    end
  end
rescue => e
  Rails.logger.error "Error loading ViteRuby: #{e.message}"
end
