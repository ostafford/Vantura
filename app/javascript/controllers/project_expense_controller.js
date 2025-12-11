import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["detailModal"]
  static values = {
    expenseId: String
  }

  connect() {
    // Close modal on Escape key
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.boundHandleEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleEscape)
  }

  openDetailModal(event) {
    event.preventDefault()
    event.stopPropagation()

    const expenseId = event.currentTarget.dataset.expenseId || event.params?.expenseId
    if (!expenseId) return

    this.expenseIdValue = expenseId

    // Show modal
    const modal = document.getElementById(`expense-detail-modal-${expenseId}`)
    if (modal) {
      modal.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  closeDetailModal(event) {
    event?.preventDefault()
    event?.stopPropagation()

    const expenseId = this.expenseIdValue || event?.currentTarget?.dataset?.expenseId
    if (!expenseId) return

    const modal = document.getElementById(`expense-detail-modal-${expenseId}`)
    if (modal) {
      modal.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  markPaid(event) {
    event.preventDefault()
    event.stopPropagation()

    // The form submission will be handled by Turbo
    // This method can be used for additional client-side logic if needed
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      const visibleModal = document.querySelector('[id^="expense-detail-modal-"]:not(.hidden)')
      if (visibleModal) {
        const expenseId = visibleModal.id.replace("expense-detail-modal-", "")
        this.expenseIdValue = expenseId
        this.closeDetailModal()
      }
    }
  }
}

