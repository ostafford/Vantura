import { Controller } from "@hotwired/stimulus"

// Toggle password visibility in password fields
export default class extends Controller {
  static targets = ["input", "button", "eyeIcon", "eyeSlashIcon"]

  connect() {
    // Ensure eye icon is visible initially
    if (this.hasEyeIconTarget) {
      this.eyeIconTarget.classList.remove('hidden')
    }
    if (this.hasEyeSlashIconTarget) {
      this.eyeSlashIconTarget.classList.add('hidden')
    }
  }

  toggle() {
    if (this.hasInputTarget) {
      const input = this.inputTarget
      const isPassword = input.type === 'password'
      
      input.type = isPassword ? 'text' : 'password'
      
      // Toggle icon visibility
      if (this.hasEyeIconTarget && this.hasEyeSlashIconTarget) {
        if (isPassword) {
          this.eyeIconTarget.classList.add('hidden')
          this.eyeSlashIconTarget.classList.remove('hidden')
        } else {
          this.eyeIconTarget.classList.remove('hidden')
          this.eyeSlashIconTarget.classList.add('hidden')
        }
      }
    }
  }
}

