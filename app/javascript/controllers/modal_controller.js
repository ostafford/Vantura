import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["modal", "form"]
  static values = {
    type: String // "transaction" or "recurring"
  }

  connect() {
    // Bind escape key
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
    
    // Initialize transaction type UI if this is a transaction modal
    if (this.typeValue === "transaction") {
      this.updateTransactionTypeUI()
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this.escapeHandler)
  }

  // Open the modal
  open(event) {
    event?.preventDefault()
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    
    if (this.typeValue === "transaction") {
      this.updateTransactionTypeUI()
    }
  }

  // Close the modal
  close(event) {
    event?.preventDefault()
    this.modalTarget.classList.add('hidden')
    this.modalTarget.classList.remove('flex')
    
    // Reset form if present
    if (this.hasFormTarget) {
      this.formTarget.reset()
      if (this.typeValue === "transaction") {
        this.updateTransactionTypeUI()
      }
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
    const radios = document.querySelectorAll('.transaction-type-radio')
    const cards = document.querySelectorAll('.transaction-type-card')
    let selectedType = 'expense'
    
    radios.forEach((radio, index) => {
      if (radio.checked) {
        selectedType = radio.value
        cards[index].classList.remove('border-gray-300', 'dark:border-gray-600', 'bg-white', 'dark:bg-gray-700')
        if (radio.value === 'expense') {
          cards[index].classList.add('border-red-500', 'dark:border-red-600', 'bg-red-50', 'dark:bg-red-900/20')
        } else {
          cards[index].classList.add('border-green-500', 'dark:border-green-600', 'bg-green-50', 'dark:bg-green-900/20')
        }
      } else {
        cards[index].classList.remove('border-red-500', 'dark:border-red-600', 'bg-red-50', 'dark:bg-red-900/20', 'border-green-500', 'dark:border-green-600', 'bg-green-50', 'dark:bg-green-900/20')
        cards[index].classList.add('border-gray-300', 'dark:border-gray-600', 'bg-white', 'dark:bg-gray-700')
      }
    })

    // Update labels based on transaction type
    const descLabel = document.getElementById('descriptionLabel')
    const amountLabel = document.getElementById('amountLabel')
    const dateLabel = document.getElementById('dateLabel')
    const descInput = document.getElementById('transactionDescription')
    
    if (selectedType === 'expense') {
      if (descLabel) descLabel.textContent = 'What are you buying?'
      if (amountLabel) amountLabel.textContent = 'How much will it cost?'
      if (dateLabel) dateLabel.textContent = 'When do you plan to buy it?'
      if (descInput) descInput.placeholder = 'e.g., New laptop, Restaurant dinner'
    } else {
      if (descLabel) descLabel.textContent = 'What income are you receiving?'
      if (amountLabel) amountLabel.textContent = 'How much will you receive?'
      if (dateLabel) dateLabel.textContent = 'When do you expect to receive it?'
      if (descInput) descInput.placeholder = 'e.g., Freelance work, Gift, Tax refund'
    }
  }
}

