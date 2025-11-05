import { Controller } from "@hotwired/stimulus"

/**
 * Modal Controller
 * 
 * Manages modal/drawer behavior for transaction forms, recurring transactions, and filters.
 * Handles opening/closing animations, escape key handling, and transaction type UI updates.
 * 
 * Cross-controller access: None (all elements are within controller scope)
 * 
 * @see .cursor/rules/conventions/code_style/stimulus_controller_style.mdc
 * @see .cursor/rules/development/hotwire/stimulus_controllers.mdc
 */
export default class extends Controller {
  static targets = [
    "modal", 
    "form", 
    "drawer", 
    "content",
    "typeRadio",
    "typeCard",
    "descriptionLabel",
    "amountLabel",
    "dateLabel",
    "transactionDescription"
  ]
  static values = {
    type: String // "transaction", "recurring", or "filter"
  }

  connect() {
    // Bind escape key
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
    
    // Initialize transaction type UI if this is a transaction modal
    if (this.typeValue === "transaction") {
      this.updateTransactionTypeUI()
    }

    // Listen for successful form submission (Turbo Streams)
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('turbo:submit-end', (event) => {
        if (event.detail.success) {
          // Close the modal with animation after successful submission
          this.close()
        }
      })
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this.escapeHandler)
  }

  // Open the drawer
  open(event) {
    event?.preventDefault()
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    
    // Pure Tailwind approach - no custom JavaScript for responsive behavior
    if (this.hasDrawerTarget && this.hasContentTarget) {
      setTimeout(() => {
        // Use Tailwind classes for responsive content shrinking
        this.contentTarget.classList.add('sm:mr-96')
        this.drawerTarget.classList.remove('translate-x-full')
        this.drawerTarget.classList.add('translate-x-0')
      }, 10)
    }
    
    if (this.typeValue === "transaction") {
      this.updateTransactionTypeUI()
    }
  }

  // Close the drawer
  close(event) {
    event?.preventDefault()
    
    // Pure Tailwind approach - use classes instead of inline styles
    if (this.hasDrawerTarget && this.hasContentTarget) {
      this.contentTarget.classList.remove('sm:mr-96')
      this.drawerTarget.classList.remove('translate-x-0')
      this.drawerTarget.classList.add('translate-x-full')
      
      // Wait for animation to complete before hiding
      setTimeout(() => {
        this.modalTarget.classList.add('hidden')
        this.modalTarget.classList.remove('flex')
      }, 300)
    } else {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
    }
    
    // Reset form if present
    if (this.hasFormTarget) {
      setTimeout(() => {
        this.formTarget.reset()
        if (this.typeValue === "transaction") {
          this.updateTransactionTypeUI()
        }
      }, 300)
    }
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

  // Transaction type UI update
  updateTransactionTypeUI() {
    // Use Stimulus targets instead of querySelector
    // Per rules: Elements within controller scope should use targets
    if (!this.hasTypeRadioTargets || !this.hasTypeCardTargets) return
    
    let selectedType = 'expense'
    
    this.typeRadioTargets.forEach((radio, index) => {
      if (radio.checked) {
        selectedType = radio.value
        const card = this.typeCardTargets[index]
        if (card) {
          card.classList.remove('border-gray-300', 'dark:border-gray-600', 'bg-white', 'dark:bg-gray-700')
          if (radio.value === 'expense') {
            card.classList.add('border-expense-500', 'dark:border-expense-500', 'bg-red-50', 'dark:bg-red-900/20')
          } else {
            card.classList.add('border-success-500', 'dark:border-success-500', 'bg-green-50', 'dark:bg-green-900/20')
          }
        }
      } else {
        const card = this.typeCardTargets[index]
        if (card) {
          card.classList.remove('border-expense-500', 'dark:border-expense-500', 'bg-red-50', 'dark:bg-red-900/20', 'border-success-500', 'dark:border-success-500', 'bg-green-50', 'dark:bg-green-900/20')
          card.classList.add('border-gray-300', 'dark:border-gray-600', 'bg-white', 'dark:bg-gray-700')
        }
      }
    })

    // Update labels based on transaction type using Stimulus targets
    // IDs are still present for form label associations and debugging
    // Per rules: Both targets AND IDs are required (targets for logic, IDs for debugging/labels)
    if (selectedType === 'expense') {
      if (this.hasDescriptionLabelTarget) {
        this.descriptionLabelTarget.textContent = 'What are you buying?'
      }
      if (this.hasAmountLabelTarget) {
        this.amountLabelTarget.textContent = 'How much will it cost?'
      }
      if (this.hasDateLabelTarget) {
        this.dateLabelTarget.textContent = 'When do you plan to buy it?'
      }
      if (this.hasTransactionDescriptionTarget) {
        this.transactionDescriptionTarget.placeholder = 'e.g., New laptop, Restaurant dinner'
      }
    } else {
      if (this.hasDescriptionLabelTarget) {
        this.descriptionLabelTarget.textContent = 'What income are you receiving?'
      }
      if (this.hasAmountLabelTarget) {
        this.amountLabelTarget.textContent = 'How much will you receive?'
      }
      if (this.hasDateLabelTarget) {
        this.dateLabelTarget.textContent = 'When do you expect to receive it?'
      }
      if (this.hasTransactionDescriptionTarget) {
        this.transactionDescriptionTarget.placeholder = 'e.g., Freelance work, Gift, Tax refund'
      }
    }
  }
}

