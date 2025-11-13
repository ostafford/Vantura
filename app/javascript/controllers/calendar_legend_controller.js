import { Controller } from "@hotwired/stimulus"

/**
 * Calendar Legend Controller
 * 
 * Handles calendar legend panel toggle.
 * Manages opening/closing the legend panel and outside click detection.
 * 
 * Attached to: Legend toggle container
 * 
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["panel", "button"]

  connect() {
    // Legend panel starts hidden
  }

  disconnect() {
    // Clean up legend click handler
    if (this.legendClickHandler) {
      document.removeEventListener('click', this.legendClickHandler)
      this.legendClickHandler = null
    }
  }

  // Toggle calendar legend visibility
  toggle(event) {
    event.stopPropagation()
    const panel = this.panelTarget || document.getElementById('calendar-legend-panel')
    if (!panel) return

    const isHidden = panel.classList.contains('hidden')
    
    if (isHidden) {
      panel.classList.remove('hidden')
      // Close on outside click
      this.legendClickHandler = (e) => {
        if (!panel.contains(e.target) && !event.target.contains(e.target)) {
          panel.classList.add('hidden')
          document.removeEventListener('click', this.legendClickHandler)
          this.legendClickHandler = null
        }
      }
      // Use setTimeout to avoid immediate trigger
      setTimeout(() => {
        document.addEventListener('click', this.legendClickHandler)
      }, 0)
    } else {
      panel.classList.add('hidden')
      if (this.legendClickHandler) {
        document.removeEventListener('click', this.legendClickHandler)
        this.legendClickHandler = null
      }
    }
  }
}

