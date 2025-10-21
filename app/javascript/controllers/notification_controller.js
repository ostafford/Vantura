import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="notification"
export default class extends Controller {
  connect() {
    // Auto-dismiss after 5 seconds
    this.autoDismissTimeout = setTimeout(() => {
      this.dismiss()
    }, 5000)
  }

  disconnect() {
    // Clear timeout if controller is disconnected before auto-dismiss
    if (this.autoDismissTimeout) {
      clearTimeout(this.autoDismissTimeout)
    }
  }

  dismiss() {
    // Fade out animation
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-20px)'
    this.element.style.transition = 'all 0.3s ease-out'
    
    // Remove after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
