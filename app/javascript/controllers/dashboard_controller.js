import { Controller } from "@hotwired/stimulus"
import { showNotification } from "../helpers/notifications"

// Connects to data-controller="dashboard"
// Handles dashboard-specific behavior including sync notification display
export default class extends Controller {
  static values = {
    syncResult: Object
  }

  connect() {
    // Show sync notification if sync result exists
    if (this.hasSyncResultValue && this.syncResultValue?.success) {
      const newTransactions = this.syncResultValue.new_transactions || 0
      const message = `${newTransactions} new transaction${newTransactions !== 1 ? 's' : ''} added`
      
      // Small delay to ensure notification container is ready
      setTimeout(() => {
        showNotification('success', message)
      }, 100)
    }
  }
}

