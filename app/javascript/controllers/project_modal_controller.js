import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["addExpenseModal", "membersModal"]

  connect() {
    // Close modal on Escape key
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.boundHandleEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleEscape)
  }

  openAddExpenseModal(event) {
    event.preventDefault()
    event.stopPropagation()

    const projectId = this.element.dataset.projectId || event.currentTarget.dataset.projectId
    if (!projectId) return

    // Load form into Turbo Frame
    const frame = document.querySelector("#project-expense-form")
    if (frame) {
      frame.src = `/projects/${projectId}/project_expenses/new`
    }

    // Show modal
    if (this.hasAddExpenseModalTarget) {
      this.addExpenseModalTarget.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  openMembersModal(event) {
    event.preventDefault()
    event.stopPropagation()

    // Show members management modal (placeholder for future implementation)
    if (this.hasMembersModalTarget) {
      this.membersModalTarget.classList.remove("hidden")
      document.body.classList.add("overflow-hidden")
    }
  }

  close(event) {
    // Close add expense modal
    if (this.hasAddExpenseModalTarget) {
      this.addExpenseModalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
      
      // Clear frame source
      const frame = document.querySelector("#project-expense-form")
      if (frame) {
        frame.src = null
      }
    }

    // Close members modal
    if (this.hasMembersModalTarget) {
      this.membersModalTarget.classList.add("hidden")
      document.body.classList.remove("overflow-hidden")
    }
  }

  formSubmitted(event) {
    // Handle form submission success
    if (event.detail.success) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      if (this.hasAddExpenseModalTarget && !this.addExpenseModalTarget.classList.contains("hidden")) {
        this.close()
      }
      if (this.hasMembersModalTarget && !this.membersModalTarget.classList.contains("hidden")) {
        this.close()
      }
    }
  }
}

