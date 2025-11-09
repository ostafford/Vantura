// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "helpers/notifications"
import { initializeHeaderHeight, calculateHeaderHeight, cleanupHeaderHeight } from "helpers/header_height"
 
// Optional: keep Turbo bar snappy if you still want it visible
Turbo.config.drive.progressBarDelay = 0

// Initialize header height calculation
function setupHeaderHeight() {
  // Initialize on DOM ready or immediately if already loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeHeaderHeight)
  } else {
    initializeHeaderHeight()
  }
}

// Initial setup
setupHeaderHeight()

// Recalculate header height on Turbo navigation events
document.addEventListener('turbo:load', () => {
  cleanupHeaderHeight()
  initializeHeaderHeight()
})

document.addEventListener('turbo:frame-load', () => {
  // Recalculate in case header content changed within a frame
  calculateHeaderHeight()
})