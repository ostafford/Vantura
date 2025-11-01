// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "helpers/notifications"
 
// Optional: keep Turbo bar snappy if you still want it visible
Turbo.config.drive.progressBarDelay = 0