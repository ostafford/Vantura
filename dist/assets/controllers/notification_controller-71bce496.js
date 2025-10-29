import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="notification"
export default class extends Controller {
  connect() {
    // Animate in (slide from right)
    setTimeout(() => {
      this.element.classList.remove('translate-x-full', 'opacity-0')
      this.element.classList.add('translate-x-0', 'opacity-100')
    }, 50) // Small delay ensures transition is visible

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
    // Slide out to the right
    this.element.classList.remove('translate-x-0', 'opacity-100')
    this.element.classList.add('translate-x-full', 'opacity-0')
    
    // Remove after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
