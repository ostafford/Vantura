import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="notification"
export default class extends Controller {
  static targets = ['container']

  static values = {
    autoDismiss: Boolean,
    dismissAfter: Number,
  }

  declare readonly hasContainerTarget: boolean
  declare readonly containerTarget: HTMLElement
  declare readonly hasAutoDismissValue: boolean
  declare autoDismissValue: boolean
  declare readonly hasDismissAfterValue: boolean
  declare dismissAfterValue: number

  private autoDismissTimeout?: number
  private animationTimeout?: number
  private removeTimeout?: number

  connect(): void {
    // Animate in (slide from right)
    this.animationTimeout = window.setTimeout(() => {
      this.element.classList.remove('translate-x-full', 'opacity-0')
      this.element.classList.add('translate-x-0', 'opacity-100')
    }, 50) // Small delay ensures transition is visible

    // Auto-dismiss if enabled
    const shouldAutoDismiss = this.hasAutoDismissValue ? this.autoDismissValue : true
    const dismissDelay = this.hasDismissAfterValue ? this.dismissAfterValue : 5000

    if (shouldAutoDismiss) {
      this.autoDismissTimeout = window.setTimeout(() => {
        this.dismiss()
      }, dismissDelay)
    }
  }

  disconnect(): void {
    // Clear timeouts if controller is disconnected before auto-dismiss
    if (this.autoDismissTimeout !== undefined) {
      window.clearTimeout(this.autoDismissTimeout)
    }
    if (this.animationTimeout !== undefined) {
      window.clearTimeout(this.animationTimeout)
    }
    if (this.removeTimeout !== undefined) {
      window.clearTimeout(this.removeTimeout)
    }
  }

  dismiss(): void {
    // Slide out to the right
    this.element.classList.remove('translate-x-0', 'opacity-100')
    this.element.classList.add('translate-x-full', 'opacity-0')

    // Remove after animation completes
    this.removeTimeout = window.setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}
