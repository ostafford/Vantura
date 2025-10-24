import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="notification"
export default class extends Controller {
  static targets = ["container"]
  
  static values = {
    autoDismiss: Boolean,
    dismissAfter: Number
  }

  connect() {
    // Animate in (slide from right)
    setTimeout(() => {
      this.element.classList.remove('translate-x-full', 'opacity-0')
      this.element.classList.add('translate-x-0', 'opacity-100')
    }, 50) // Small delay ensures transition is visible

    // Auto-dismiss if enabled
    const shouldAutoDismiss = this.hasAutoDismissValue ? this.autoDismissValue : true
    const dismissDelay = this.hasDismissAfterValue ? this.dismissAfterValue : 5000
    
    if (shouldAutoDismiss) {
      this.autoDismissTimeout = setTimeout(() => {
        this.dismiss()
      }, dismissDelay)
    }
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
