import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["amount", "spent", "remaining", "percentage", "progressBar"]
  static values = { 
    limit: Number,
    spent: Number 
  }

  connect() {
    this.updateDisplay()
  }

  limitValueChanged() {
    this.updateDisplay()
  }

  spentValueChanged() {
    this.updateDisplay()
  }

  updateDisplay() {
    const limit = this.limitValue || 0
    const spent = this.spentValue || 0
    const remaining = limit - spent
    const percentage = limit > 0 ? (spent / limit * 100) : 0

    // Format currency (AUD)
    this.amountTarget.textContent = this.formatCurrency(limit)
    this.spentTarget.textContent = this.formatCurrency(spent)
    this.remainingTarget.textContent = this.formatCurrency(remaining)
    this.percentageTarget.textContent = `${percentage.toFixed(1)}%`

    // Update progress bar
    const progressBar = this.progressBarTarget
    const percentageValue = Math.min(percentage, 100)
    progressBar.style.width = `${percentageValue}%`
    
    // Color coding based on percentage
    // Remove all color classes first
    progressBar.classList.remove("bg-green-500", "bg-yellow-500", "bg-red-500")
    
    if (percentage >= 100) {
      progressBar.classList.add("bg-red-500")
    } else if (percentage >= 80) {
      progressBar.classList.add("bg-yellow-500")
    } else {
      progressBar.classList.add("bg-green-500")
    }
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount)
  }
}

