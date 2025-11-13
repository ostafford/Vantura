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

// Temporary diagnostics for Turbo navigation behaviour
if (import.meta.env?.DEV ?? true) {
  const debugTurboEvent = (name) => (event) => {
    console.debug(`[turbo:${name}]`, {
      url: event.detail?.url,
      frame: event.target?.id,
      action: event.detail?.action
    })
  }

  document.addEventListener("turbo:before-visit", debugTurboEvent("before-visit"))
  document.addEventListener("turbo:visit", debugTurboEvent("visit"))
  document.addEventListener("turbo:load", () => console.debug("[turbo:load]"))
  document.addEventListener("turbo:before-cache", () => console.debug("[turbo:before-cache]"))
  document.addEventListener("turbo:before-frame-render", debugTurboEvent("before-frame-render"))
  document.addEventListener("turbo:frame-load", debugTurboEvent("frame-load"))
}