import { Controller } from "@hotwired/stimulus"

/**
 * Recurring Modal Controller
 * 
 * Manages recurring transaction form behavior.
 * On desktop: integrates with sidebar to expand and show form within sidebar.
 * On mobile: uses drawer behavior (slides in from right).
 * 
 * Cross-controller access:
 * - Sidebar controller (via getElementById) - Shared layout element, acceptable per rules
 */
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
    
    // Ensure modal is hidden first (in case it was previously shown)
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
    }
    
    // Check if we're on desktop (lg breakpoint)
    const isDesktop = this.mediaQuery?.matches ?? window.innerWidth >= 1024
    
    // Re-check sidebar controller and form container (they might not be initialized yet)
    if (!this.sidebarController || !this.sidebarFormContainer) {
      this.sidebarElement = document.querySelector('[data-controller*="sidebar"]')
      this.sidebarController = this.sidebarElement ? this.application.getControllerForElementAndIdentifier(this.sidebarElement, 'sidebar') : null
      this.sidebarFormContainer = document.getElementById('sidebar-form-container')
    }
    
    if (isDesktop && this.sidebarController && this.sidebarFormContainer && this.hasDrawerTarget) {
      // Desktop: Use sidebar expansion
      this.openInSidebar()
    } else {
      // Mobile: Use drawer behavior
      this.openAsDrawer()
    }
  }
  
  // Open form in sidebar (desktop)
  openInSidebar() {
    // Ensure drawer is reset to initial state (hidden, translated out)
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.remove('translate-x-0')
      this.drawerTarget.classList.add('translate-x-full')
    }
    if (this.hasContentTarget) {
      this.contentTarget.style.marginRight = '0'
    }
    
    // Enter sidebar form mode
    if (this.sidebarController) {
      this.sidebarController.enterFormMode()
    }
    
    // Clone drawer content and inject into sidebar form container
    if (this.hasDrawerTarget && this.sidebarFormContainer) {
      // Clear existing content
      this.sidebarFormContainer.innerHTML = ''
      
      // Clone the drawer content (excluding the fixed positioning classes)
      const drawerContent = this.drawerTarget.cloneNode(true)
      
      // Extract header (gradient header) and move it to sidebar header position
      const formHeader = drawerContent.querySelector('.bg-gradient-to-r')
      const sidebarHeader = this.sidebarController?.headerTarget
      
      if (formHeader && sidebarHeader) {
        // Store original header HTML if not already stored
        if (!this.sidebarController.originalHeaderHTML) {
          this.sidebarController.originalHeaderHTML = sidebarHeader.innerHTML
        }
        
        // Clone header and inject into sidebar header position
        const clonedHeader = formHeader.cloneNode(true)
        // Remove the original header from drawer content
        formHeader.remove()
        // Replace sidebar header content with form header
        sidebarHeader.innerHTML = clonedHeader.innerHTML
        sidebarHeader.classList.remove('hidden')
        // Update header classes to match form header styling
        sidebarHeader.classList.add('bg-gradient-to-r', 'from-info-500', 'via-info-700', 'to-info-500', 'dark:from-info-700', 'dark:via-info-900', 'dark:to-info-700', 'px-6', 'py-5')
        sidebarHeader.classList.remove('py-4', 'px-4')
      }
      
      // Remove fixed positioning classes and make it fit sidebar
      drawerContent.classList.remove('fixed', 'inset-y-0', 'right-0', 'w-full', 'sm:w-96', 'translate-x-full', 'translate-x-0', 'border-l-2', 'md:top-16', 'md:bottom-0')
      drawerContent.classList.add('w-full', 'h-full', 'flex', 'flex-col')
      
      // Append to sidebar form container
      this.sidebarFormContainer.appendChild(drawerContent)
      
      // Re-initialize targets in the new location (match modal controller - use drawerContent)
      this.reinitializeTargets(drawerContent)
      
      // Re-initialize close button in header (match modal controller pattern)
      if (sidebarHeader) {
        const headerCloseButton = sidebarHeader.querySelector('button[type="button"]')
        if (headerCloseButton) {
          headerCloseButton.removeAttribute('data-action')
          headerCloseButton.addEventListener('click', (e) => {
            e.preventDefault()
            e.stopPropagation()
            this.close(e)
          })
        }
      }
    }
    
    // Keep modal hidden on desktop (form is in sidebar, not in modal)
    // Modal container remains in DOM for form submission tracking
    this.modalTarget.classList.add('hidden')
    this.modalTarget.classList.remove('flex')
  }
  
  // Open as drawer (mobile)
  openAsDrawer() {
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    
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
  
  // Re-initialize targets after cloning
  reinitializeTargets(clonedElement) {
    // Update target references
    this.descriptionTarget = clonedElement.querySelector('[data-recurring-modal-target="description"]')
    this.amountTarget = clonedElement.querySelector('[data-recurring-modal-target="amount"]')
    this.transactionIdTarget = clonedElement.querySelector('[data-recurring-modal-target="transactionId"]')
    this.nextOccurrenceDateTarget = clonedElement.querySelector('[data-recurring-modal-target="nextOccurrenceDate"]')
    this.frequencySelectTarget = clonedElement.querySelector('[data-recurring-modal-target="frequencySelect"]')
    this.categorySelectTarget = clonedElement.querySelector('[data-recurring-modal-target="categorySelect"]')
    this.categoryFrameTarget = clonedElement.querySelector('[data-recurring-modal-target="categoryFrame"]')
    
    // Find form and update reference
    const clonedForm = clonedElement.querySelector('form')
    if (clonedForm && this.hasFormTarget) {
      this.formTargets = [clonedForm]
    }
    
    // Re-attach close button handlers (match modal controller pattern exactly)
    // Find close buttons by data-action or by ID/class patterns (avoid submit buttons)
    const closeButtons = clonedElement.querySelectorAll(
      '[data-action*="recurring-modal#close"], ' +
      'button[type="button"][id*="cancel"], ' +
      'button[type="button"][id*="close"], ' +
      'button[type="button"]:not([type="submit"])'
    )
    closeButtons.forEach((button) => {
      // Skip submit buttons explicitly
      if (button.type === 'submit' || button.closest('form')?.querySelector('button[type="submit"]') === button) {
        return
      }
      
      // Only handle buttons that are clearly close/cancel buttons
      const isCloseButton = button.getAttribute('data-action')?.includes('recurring-modal#close') ||
                           button.id?.includes('cancel') ||
                           button.id?.includes('close') ||
                           button.textContent?.trim().toLowerCase() === 'cancel'
      
      if (!isCloseButton) return
      
      // Remove data-action to prevent Stimulus from trying to bind
      button.removeAttribute('data-action')
      // Remove any existing listeners by cloning
      const newButton = button.cloneNode(true)
      button.parentNode.replaceChild(newButton, button)
      // Add click handler (use arrow function like modal controller)
      newButton.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()
        this.close(e)
      })
    })
    
    // Re-attach event listeners
    if (this.frequencySelectTarget) {
      this.frequencySelectTarget.addEventListener('change', (e) => this.updateNextOccurrenceDate(e))
    }
    
    if (this.categorySelectTarget) {
      this.categorySelectTarget.addEventListener('change', (e) => this.toggleCustomCategory(e))
    }
    
    // Re-attach tolerance type toggle
    const toleranceTypeSelect = clonedElement.querySelector('#recurring-tolerance-type-select')
    if (toleranceTypeSelect) {
      toleranceTypeSelect.addEventListener('change', (e) => this.toggleToleranceType(e))
    }
    
    // Re-attach auto-detect button
    const autoDetectButton = clonedElement.querySelector('#auto-detect-frequency-button')
    if (autoDetectButton) {
      autoDetectButton.addEventListener('click', (e) => this.autoDetectFrequency(e))
    }
    
    // Update values in cloned element
    if (this.transactionIdTarget) {
      this.transactionIdTarget.value = this.currentTransactionId
    }
    
    // Re-setup category frame if needed
    if (this.hasCategoryFrameTarget && this.currentTransactionId) {
      const url = `/recurring_transactions/available_categories?transaction_id=${this.currentTransactionId}`
      this.categoryFrameTarget.src = url
    }
  }

  // Close the recurring drawer
  close(event) {
    event?.preventDefault()
    
    if (!this.hasModalTarget) return
    
    // Check if we're on desktop
    const isDesktop = this.mediaQuery.matches
    
    if (isDesktop && this.sidebarController) {
      // Desktop: Exit sidebar form mode
      this.closeFromSidebar()
    } else {
      // Mobile: Close drawer
      this.closeDrawer()
    }
  }
  
  // Close from sidebar (desktop)
  closeFromSidebar() {
    // Restore sidebar header
    if (this.sidebarController?.headerTarget && this.sidebarController.originalHeaderHTML) {
      const sidebarHeader = this.sidebarController.headerTarget
      // Restore original header HTML
      sidebarHeader.innerHTML = this.sidebarController.originalHeaderHTML
      // Reset header classes
      sidebarHeader.classList.remove('bg-gradient-to-r', 'from-info-500', 'via-info-700', 'to-info-500', 'dark:from-info-700', 'dark:via-info-900', 'dark:to-info-700', 'px-6', 'py-5')
      sidebarHeader.classList.add('py-4', 'px-4')
      // Clear stored HTML (will be re-stored on next open if needed)
      this.sidebarController.originalHeaderHTML = null
    }
    
    // Exit sidebar form mode
    if (this.sidebarController) {
      this.sidebarController.exitFormMode()
    }
    
    // Clear sidebar form container
    if (this.sidebarFormContainer) {
      this.sidebarFormContainer.innerHTML = ''
    }
    
    // Hide modal
    this.modalTarget.classList.add('hidden')
    this.modalTarget.classList.remove('flex')
    
    // Reset form and state (use original form target)
    if (this.hasFormTarget) {
      setTimeout(() => {
        this.formTarget.reset()
        // Reset category frame for next open
        if (this.hasCategoryFrameTarget) {
          this.categoryFrameTarget.src = ''
        }
        this.currentTransactionId = null
        this.currentTransactionDate = null
      }, 300)
    } else {
      // Reset category frame for next open
      if (this.hasCategoryFrameTarget) {
        this.categoryFrameTarget.src = ''
      }
      this.currentTransactionId = null
      this.currentTransactionDate = null
    }
  }
  
  // Close drawer (mobile)
  closeDrawer() {
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
    // Cross-controller access: sidebar is shared layout element
    this.sidebarElement = document.querySelector('[data-controller*="sidebar"]')
    this.sidebarController = this.sidebarElement ? this.application.getControllerForElementAndIdentifier(this.sidebarElement, 'sidebar') : null
    this.sidebarFormContainer = document.getElementById('sidebar-form-container')
    
    // Media query for responsive behavior
    this.mediaQuery = window.matchMedia('(min-width: 1024px)')
    
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
  }

  disconnect() {
    document.removeEventListener('keydown', this.escapeHandler)
  }
}



