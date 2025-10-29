import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="recurring-modal"
export default class extends Controller {
  static targets = [
    'modal',
    'form',
    'description',
    'amount',
    'transactionId',
    'nextOccurrenceDate',
    'frequencySelect',
    'drawer',
    'content',
  ]

  declare readonly hasModalTarget: boolean
  declare readonly modalTarget: HTMLElement
  declare readonly hasFormTarget: boolean
  declare readonly formTarget: HTMLFormElement
  declare readonly hasDescriptionTarget: boolean
  declare readonly descriptionTarget: HTMLElement
  declare readonly hasAmountTarget: boolean
  declare readonly amountTarget: HTMLElement
  declare readonly hasTransactionIdTarget: boolean
  declare readonly transactionIdTarget: HTMLInputElement
  declare readonly hasNextOccurrenceDateTarget: boolean
  declare readonly nextOccurrenceDateTarget: HTMLInputElement
  declare readonly hasFrequencySelectTarget: boolean
  declare readonly frequencySelectTarget: HTMLSelectElement
  declare readonly hasDrawerTarget: boolean
  declare readonly drawerTarget: HTMLElement
  declare readonly hasContentTarget: boolean
  declare readonly contentTarget: HTMLElement

  currentTransactionId: string | null = null
  currentTransactionDate: string | null = null

  private escapeHandler?: (e: KeyboardEvent) => void
  private closeTimeout?: number

  // Open the recurring drawer
  open(event: Event): void {
    event.preventDefault()

    const button = event.currentTarget as HTMLElement
    this.currentTransactionId = button.dataset.transactionId || null
    this.currentTransactionDate = button.dataset.transactionDate || null
    const description = button.dataset.description || ''
    const amount = parseFloat(button.dataset.amount || '0')

    // Set values
    if (this.hasTransactionIdTarget && this.currentTransactionId) {
      this.transactionIdTarget.value = this.currentTransactionId
    }
    if (this.hasDescriptionTarget) {
      this.descriptionTarget.textContent = description
    }

    const formattedAmount = (amount < 0 ? '-' : '+') + '$' + Math.abs(amount).toFixed(2)
    const amountColor =
      amount < 0 ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'
    if (this.hasAmountTarget) {
      this.amountTarget.textContent = formattedAmount
      this.amountTarget.className = 'font-semibold ' + amountColor
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
  close(event?: Event): void {
    event?.preventDefault()

    // Slide out drawer and restore content width
    if (this.hasDrawerTarget && this.hasContentTarget) {
      this.contentTarget.style.marginRight = '0'
      this.drawerTarget.classList.remove('translate-x-0')
      this.drawerTarget.classList.add('translate-x-full')

      // Wait for animation to complete before hiding
      this.closeTimeout = window.setTimeout(() => {
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
  updateNextOccurrenceDate(event: Event): void {
    const select = event.target as HTMLSelectElement
    const frequency = select.value
    if (!frequency || !this.currentTransactionDate) return

    const txnDate = new Date(this.currentTransactionDate)
    const nextDate = new Date(txnDate)

    switch (frequency) {
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
    if (this.hasNextOccurrenceDateTarget) {
      this.nextOccurrenceDateTarget.value = formatted
    }
  }

  // Close on background click
  closeOnBackground(event: MouseEvent): void {
    if (event.target === this.modalTarget) {
      this.close(event)
    }
  }

  // Handle escape key
  handleEscape(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  connect(): void {
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
  }

  disconnect(): void {
    if (this.escapeHandler) {
      document.removeEventListener('keydown', this.escapeHandler)
    }
    if (this.closeTimeout !== undefined) {
      window.clearTimeout(this.closeTimeout)
    }
  }
}
