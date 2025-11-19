import { Controller } from "@hotwired/stimulus"

/**
 * Deletion Controller
 * 
 * Manages account deletion confirmation form validation.
 * Requires user to type "DELETE" exactly before enabling submit button.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = ["input", "submit", "error"]
  static values = {
    requiredText: { type: String, default: "DELETE" }
  }

  connect() {
    // Disable submit button initially
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }

  validate(event) {
    const inputValue = event.target.value.trim()
    const isValid = inputValue === this.requiredTextValue
    
    // Update submit button state
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !isValid
      if (isValid) {
        this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
        this.submitTarget.classList.add("hover:bg-expense-700")
      } else {
        this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
        this.submitTarget.classList.remove("hover:bg-expense-700")
      }
    }
    
    // Update aria-invalid
    if (this.hasInputTarget) {
      this.inputTarget.setAttribute("aria-invalid", (!isValid && inputValue.length > 0).toString())
    }
    
    // Show/hide error message
    if (this.hasErrorTarget) {
      if (!isValid && inputValue.length > 0) {
        this.errorTarget.classList.remove("hidden")
      } else {
        this.errorTarget.classList.add("hidden")
      }
    }
  }
}

