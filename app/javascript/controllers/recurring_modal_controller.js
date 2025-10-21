import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recurring-modal"
export default class extends Controller {
  static targets = ["modal", "form", "description", "amount", "transactionId", "nextOccurrenceDate", "frequencySelect"]
  
  currentTransactionId = null
  currentTransactionDate = null

  // Open the recurring modal
  open(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    this.currentTransactionId = button.dataset.transactionId
    this.currentTransactionDate = button.dataset.transactionDate
    const description = button.dataset.description
    const amount = parseFloat(button.dataset.amount)
    
    // Set values
    this.transactionIdTarget.value = this.currentTransactionId
    this.descriptionTarget.textContent = description
    
    const formattedAmount = (amount < 0 ? '-' : '+') + '$' + Math.abs(amount).toFixed(2)
    const amountColor = amount < 0 ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'
    this.amountTarget.textContent = formattedAmount
    this.amountTarget.className = 'font-medium ' + amountColor
    
    // Show modal
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
  }

  // Close the recurring modal
  close(event) {
    event?.preventDefault()
    this.modalTarget.classList.add('hidden')
    this.modalTarget.classList.remove('flex')
    this.formTarget.reset()
    this.currentTransactionId = null
    this.currentTransactionDate = null
  }

  // Update next occurrence date when frequency changes
  updateNextOccurrenceDate(event) {
    const frequency = this.frequencySelectTarget.value
    if (!frequency || !this.currentTransactionDate) return
    
    const txnDate = new Date(this.currentTransactionDate)
    let nextDate = new Date(txnDate)
    
    switch(frequency) {
      case 'weekly':
        nextDate.setDate(nextDate.getDate() + 7)
        break
      case 'fortnightly':
        nextDate.setDate(nextDate.getDate() + 14)
        break
      case 'monthly':
        nextDate.setMonth(nextDate.getMonth() + 1)
        break
      case 'quarterly':
        nextDate.setMonth(nextDate.getMonth() + 3)
        break
      case 'yearly':
        nextDate.setFullYear(nextDate.getFullYear() + 1)
        break
    }
    
    // Format as YYYY-MM-DD for date input
    const formatted = nextDate.toISOString().split('T')[0]
    this.nextOccurrenceDateTarget.value = formatted
  }

  // Close on background click
  closeOnBackground(event) {
    if (event.target === this.modalTarget) {
      this.close(event)
    }
  }

  // Handle escape key
  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  connect() {
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
  }

  disconnect() {
    document.removeEventListener('keydown', this.escapeHandler)
  }
}

