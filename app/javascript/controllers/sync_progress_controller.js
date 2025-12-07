import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["redirect", "progressBar", "steps"]
  static values = { userId: Number }

  connect() {
    // Use MutationObserver to watch for completion element changes
    const completionEl = document.getElementById("completion-redirect")
    if (completionEl) {
      this.observer = new MutationObserver(() => {
        if (!completionEl.classList.contains("hidden") && completionEl.children.length > 0) {
          this.showRedirect()
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
    }, 1000)
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
      this.showRedirect()
      if (this.checkInterval) {
        clearInterval(this.checkInterval)
      }
    }
  }

  showRedirect() {
    const completionEl = document.getElementById("completion-redirect")
    if (!completionEl) return

    // Countdown from 3
    let seconds = 3
    const countdownEl = document.getElementById("countdown")
    
    const updateCountdown = () => {
      if (countdownEl) {
        countdownEl.textContent = `Redirecting in ${seconds} second${seconds !== 1 ? 's' : ''}...`
      }
    }
    
    updateCountdown()
    
    const interval = setInterval(() => {
      seconds--
      updateCountdown()
      
      if (seconds === 0) {
        clearInterval(interval)
        window.location.href = "/dashboard"
      }
    }, 1000)
  }
}

