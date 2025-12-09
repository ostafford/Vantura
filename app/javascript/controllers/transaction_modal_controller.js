import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]
  static values = {
    transactionId: String
  }

  connect() {
    // Close modal on Escape key
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.boundHandleEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleEscape)
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget.closest("[data-transaction-id]") || event.currentTarget
    const transactionId = button.dataset.transactionId || event.params?.transactionId
    if (!transactionId) return

    this.transactionIdValue = transactionId
    
    // Set the Turbo Frame source to load transaction details
    const frame = document.getElementById("transaction-detail")
    if (frame) {
      frame.src = `/transactions/${transactionId}`
    }

    // Show modal
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    } else {
      // Fallback: navigate to transaction page
      Turbo.visit(`/transactions/${transactionId}`)
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
      
      // Clear frame source
      const frame = document.getElementById("transaction-detail")
      if (frame) {
        frame.src = null
      }
    }
  }

  handleEscape(event) {
    if (event.key === "Escape" && this.hasModalTarget && !this.modalTarget.classList.contains("hidden")) {
      this.close()
    }
  }
}

