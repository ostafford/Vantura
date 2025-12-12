import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "feedback", "toggle", "eyeIcon", "eyeSlashIcon"]

  connect() {
    this.validate()
  }

  validate() {
    const token = this.inputTarget.value.trim()
    
    // Basic format validation
    if (token.length === 0) {
      this.setFeedback("", "")
      if (this.hasButtonTarget) {
        this.buttonTarget.disabled = true
      }
      return
    }

    if (token.startsWith("up:") && token.length > 20) {
      this.setFeedback("Format looks good", "text-green-600 dark:text-green-400")
      if (this.hasButtonTarget) {
        this.buttonTarget.disabled = false
      }
    } else {
      this.setFeedback("Token format invalid. Should start with 'up:' and be at least 20 characters.", "text-red-600 dark:text-red-400")
      if (this.hasButtonTarget) {
        this.buttonTarget.disabled = true
      }
    }
  }

  toggleVisibility() {
    const input = this.inputTarget
    
    if (input.type === "password") {
      input.type = "text"
      if (this.hasEyeIconTarget) {
        this.eyeIconTarget.classList.add('hidden')
      }
      if (this.hasEyeSlashIconTarget) {
        this.eyeSlashIconTarget.classList.remove('hidden')
      }
    } else {
      input.type = "password"
      if (this.hasEyeIconTarget) {
        this.eyeIconTarget.classList.remove('hidden')
      }
      if (this.hasEyeSlashIconTarget) {
        this.eyeSlashIconTarget.classList.add('hidden')
      }
    }
  }

  setFeedback(message, className) {
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.textContent = message
      if (message) {
        this.feedbackTarget.className = `mt-1 text-xs ${className}`
        this.feedbackTarget.classList.remove('hidden')
      } else {
        this.feedbackTarget.classList.add('hidden')
      }
    }
  }
}

