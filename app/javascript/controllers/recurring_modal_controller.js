import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recurring-modal"
export default class extends Controller {
  static targets = ["modal", "form", "description", "amount", "transactionId", "nextOccurrenceDate", "frequencySelect", "drawer", "content"]
  
  currentTransactionId = null
  currentTransactionDate = null

  // Open the recurring drawer
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
    this.amountTarget.className = 'font-semibold ' + amountColor
    
    // Show container
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    
    // Shrink content and slide in drawer
    if (this.hasDrawerTarget && this.hasContentTarget) {
      setTimeout(() => {
        // Add right margin to shrink content (responsive - only on desktop)
        if (window.innerWidth >= 640) {
          this.contentTarget.style.marginRight = '384px'
        }
        this.drawerTarget.classList.remove('translate-x-full')
        this.drawerTarget.classList.add('translate-x-0')
      }, 10)
    }
  }

  // Close the recurring drawer
  close(event) {
    event?.preventDefault()
    
    if (!this.hasModalTarget) return
    
    // Slide out drawer and restore content width
    if (this.hasDrawerTarget && this.hasContentTarget) {
      this.contentTarget.style.marginRight = '0'
      this.drawerTarget.classList.remove('translate-x-0')
      this.drawerTarget.classList.add('translate-x-full')
      
      // Wait for animation to complete before hiding
      setTimeout(() => {
        this.modalTarget.classList.add('hidden')
        this.modalTarget.classList.remove('flex')
        if (this.hasFormTarget) {
          this.formTarget.reset()
        }
        this.currentTransactionId = null
        this.currentTransactionDate = null
      }, 300)
    } else {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
      if (this.hasFormTarget) {
        this.formTarget.reset()
      }
      this.currentTransactionId = null
      this.currentTransactionDate = null
    }
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
    if (event.key === 'Escape' && this.hasModalTarget) {
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

