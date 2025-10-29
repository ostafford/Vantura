import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sync"
export default class extends Controller {
  static targets = ["icon"]

  // Add spinning animation when form is submitted
  submit(event) {
    if (this.hasIconTarget) {
      this.iconTarget.classList.add('animate-spin')
    }
  }
}

