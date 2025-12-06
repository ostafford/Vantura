import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  showDetails(event) {
    const transactionId = event.currentTarget.dataset.transactionId
    // Navigate to transaction detail page or open modal
    Turbo.visit(`/transactions/${transactionId}`)
  }
}

