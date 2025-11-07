import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recurring-modal"
export default class extends Controller {
  static targets = ["modal", "form", "description", "amount", "transactionId", "nextOccurrenceDate", "frequencySelect", "drawer", "content", "categorySelect", "categoryFrame"]
  
  currentTransactionId = null
  currentTransactionDate = null
  
  // Pre-defined categories
  PREDEFINED_INCOME = ['salary', 'freelance', 'investment', 'rental', 'other']
  PREDEFINED_EXPENSE = ['subscription', 'bill', 'loan', 'insurance', 'other']

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
    
    // Load categories via Turbo Frame lazy-loading
    if (this.hasCategoryFrameTarget) {
      const url = `/recurring_transactions/available_categories?transaction_id=${this.currentTransactionId}`
      
      // Set src attribute directly - Turbo Frame will automatically load when src is set
      this.categoryFrameTarget.src = url
      
      // Smart defaults for income transactions - wait for frame to load
      if (amount > 0) {
        const handleCategoryLoad = (event) => {
          // Only handle if this is our frame
          if (event.target === this.categoryFrameTarget) {
            // Pre-select "salary" category for income
            if (this.hasCategorySelectTarget) {
              const salaryOption = this.categorySelectTarget.querySelector('option[value="salary"]')
              if (salaryOption) {
                this.categorySelectTarget.value = 'salary'
              }
            }
            this.categoryFrameTarget.removeEventListener('turbo:frame-load', handleCategoryLoad)
          }
        }
        this.categoryFrameTarget.addEventListener('turbo:frame-load', handleCategoryLoad)
      }
    }
    
    // Smart defaults for income transactions
    if (amount > 0) {
      // Pre-select monthly frequency for income
      if (this.frequencySelectTarget && !this.frequencySelectTarget.value) {
        this.frequencySelectTarget.value = 'monthly'
        this.updateNextOccurrenceDate({ target: this.frequencySelectTarget })
      }
    }
    
    // Reset frequency suggestion
    const suggestionDiv = document.getElementById('frequency-suggestion')
    if (suggestionDiv) {
      suggestionDiv.classList.add('hidden')
      suggestionDiv.textContent = ''
    }
    
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
        // Reset category frame for next open
        if (this.hasCategoryFrameTarget) {
          this.categoryFrameTarget.src = ''
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
      // Reset category frame for next open
      if (this.hasCategoryFrameTarget) {
        this.categoryFrameTarget.src = ''
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

  // Auto-detect frequency from transaction history
  async autoDetectFrequency(event) {
    event.preventDefault()
    
    if (!this.currentTransactionId) return
    
    const button = event.currentTarget
    button.disabled = true
    button.textContent = 'Detecting...'
    
    try {
      const response = await fetch(`/recurring_transactions/suggest_frequency?transaction_id=${this.currentTransactionId}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      const data = await response.json()
      
      if (data.frequency && data.confidence > 0) {
        // Set the frequency
        this.frequencySelectTarget.value = data.frequency
        this.updateNextOccurrenceDate({ target: this.frequencySelectTarget })
        
        // Show suggestion
        const suggestionDiv = document.getElementById('frequency-suggestion')
        if (suggestionDiv) {
          const frequencyLabel = data.frequency.charAt(0).toUpperCase() + data.frequency.slice(1)
          suggestionDiv.textContent = `Suggested: ${frequencyLabel} (${data.confidence}% confidence)`
          suggestionDiv.classList.remove('hidden')
        }
      } else {
        // No suggestion found
        const suggestionDiv = document.getElementById('frequency-suggestion')
        if (suggestionDiv) {
          suggestionDiv.textContent = 'No pattern detected. Please select manually.'
          suggestionDiv.classList.remove('hidden')
          suggestionDiv.className = 'mt-2 text-xs text-gray-500 dark:text-gray-400'
        }
      }
    } catch (error) {
      console.error('Error detecting frequency:', error)
      const suggestionDiv = document.getElementById('frequency-suggestion')
      if (suggestionDiv) {
        suggestionDiv.textContent = 'Unable to detect pattern. Please select manually.'
        suggestionDiv.classList.remove('hidden')
        suggestionDiv.className = 'mt-2 text-xs text-red-500 dark:text-red-400'
      }
    } finally {
      button.disabled = false
      button.textContent = 'Auto-detect'
    }
  }

  // Toggle between fixed and percentage tolerance
  toggleToleranceType(event) {
    const toleranceType = event.target.value
    const fixedField = document.getElementById('fixed-tolerance-field')
    const percentageField = document.getElementById('percentage-tolerance-field')
    
    if (toleranceType === 'percentage') {
      fixedField.classList.add('hidden')
      percentageField.classList.remove('hidden')
    } else {
      fixedField.classList.remove('hidden')
      percentageField.classList.add('hidden')
    }
  }


  // Toggle custom category input when "other" is selected
  toggleCustomCategory(event) {
    const categorySelect = event.target
    const customCategoryField = document.getElementById('custom-category-field')
    const customCategoryInput = document.getElementById('custom-category-name-input')
    
    if (categorySelect.value === 'other') {
      customCategoryField.classList.remove('hidden')
      customCategoryInput.required = true
    } else {
      customCategoryField.classList.add('hidden')
      customCategoryInput.required = false
      customCategoryInput.value = ''
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

