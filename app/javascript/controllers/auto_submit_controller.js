import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    debounceMs: { type: Number, default: 500 }
  }

  connect() {
    this.debounceTimer = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  submit(event) {
    event.preventDefault()
    this.element.requestSubmit()
  }

  debouncedSubmit(event) {
    event.preventDefault()
    
    // Clear existing timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Set new timer
    this.debounceTimer = setTimeout(() => {
      this.element.requestSubmit()
    }, this.debounceMsValue)
  }
}

