import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["redirect"]
  static values = { userId: Number }

  connect() {
    // Watch for completion element changes
    const completionEl = document.getElementById("completion-redirect")
    if (completionEl) {
      this.observer = new MutationObserver(() => {
        if (!completionEl.classList.contains("hidden") && completionEl.children.length > 0) {
          this.showCompletion()
        }
      })
      
      this.observer.observe(completionEl, {
        attributes: true,
        attributeFilter: ['class'],
        childList: true,
        subtree: true
      })
    }

    // Also check periodically as fallback
    this.checkInterval = setInterval(() => {
      this.checkCompletion()
    }, 500)  // Check every 500ms
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.checkInterval) {
      clearInterval(this.checkInterval)
    }
  }

  checkCompletion() {
    const completionEl = document.getElementById("completion-redirect")
    if (completionEl && !completionEl.classList.contains("hidden") && completionEl.children.length > 0) {
      this.showCompletion()
      // Stop checking once we find it
      if (this.checkInterval) {
        clearInterval(this.checkInterval)
      }
    }
  }

  showCompletion() {
    const completionEl = document.getElementById("completion-redirect")
    if (!completionEl) return
    
    // Remove hidden class to reveal the completion message
    completionEl.classList.remove("hidden")
    
    // The countdown controller (from _completion.html.erb) will handle the redirect
  }
}