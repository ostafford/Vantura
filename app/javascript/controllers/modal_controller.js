import { Controller } from "@hotwired/stimulus"

/**
 * Modal Controller
 * 
 * Manages modal/drawer behavior for transaction forms, recurring transactions, and filters.
 * Handles opening/closing animations, escape key handling, and transaction type UI updates.
 * On desktop: integrates with sidebar to expand and show form within sidebar.
 * On mobile: uses drawer behavior (slides in from right).
 * 
 * Cross-controller access:
 * - Sidebar controller (via getElementById) - Shared layout element, acceptable per rules
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
    "overlay",
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
    // Cross-controller access: sidebar is shared layout element
    this.sidebarElement = document.querySelector('[data-controller*="sidebar"]')
    this.sidebarController = this.sidebarElement ? this.application.getControllerForElementAndIdentifier(this.sidebarElement, 'sidebar') : null
    this.sidebarFormContainer = document.getElementById('sidebar-form-container')
    
    // Media query for responsive behavior
    this.mediaQuery = window.matchMedia('(min-width: 1024px)')
    
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
    
    // Ensure modal is hidden first (in case it was previously shown)
    this.modalTarget.classList.add('hidden')
    this.modalTarget.classList.remove('flex')
    
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
    
    if (this.typeValue === "transaction") {
      this.updateTransactionTypeUI()
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
      this.contentTarget.classList.remove('sm:mr-96')
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
      
      // Remove overlay if present (we don't need it in sidebar)
      const overlay = drawerContent.querySelector('[data-modal-target="overlay"]')
      if (overlay) {
        overlay.remove()
      }
      
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
      drawerContent.classList.remove('fixed', 'inset-y-0', 'right-0', 'w-full', 'sm:w-96', 'translate-x-full', 'translate-x-0', 'border-l-2', 'md:top-16', 'md:bottom-0', 'z-50')
      drawerContent.classList.add('w-full', 'h-full', 'flex', 'flex-col')
      
      // Append to sidebar form container
      this.sidebarFormContainer.appendChild(drawerContent)
      
      // Re-initialize form targets in the new location
      this.reinitializeFormTargets(drawerContent)
      
      // Re-initialize close button in header
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
        // Use Tailwind classes for responsive content shrinking
        this.contentTarget.classList.add('sm:mr-96')
        this.drawerTarget.classList.remove('translate-x-full')
        this.drawerTarget.classList.add('translate-x-0')
      }, 10)
    }
  }
  
  // Re-initialize form targets after cloning
  reinitializeFormTargets(clonedElement) {
    // Find form in cloned element and update targets
    const clonedForm = clonedElement.querySelector('form')
    if (clonedForm && this.hasFormTarget) {
      // Update form target reference
      this.formTargets = [clonedForm]
      
      // Re-attach event listeners
      clonedForm.addEventListener('turbo:submit-end', (event) => {
        if (event.detail.success) {
          this.close()
        }
      })
    }
    
    // Re-attach close button handlers
    // Find close buttons by data-action or by ID/class patterns (avoid submit buttons)
    const closeButtons = clonedElement.querySelectorAll(
      '[data-action*="modal#close"], ' +
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
      const isCloseButton = button.getAttribute('data-action')?.includes('modal#close') ||
                           button.id?.includes('cancel') ||
                           button.id?.includes('close') ||
                           button.textContent?.trim().toLowerCase() === 'cancel'
      
      if (!isCloseButton) return
      
      // Remove data-action to prevent Stimulus from trying to bind
      button.removeAttribute('data-action')
      // Remove any existing listeners by cloning
      const newButton = button.cloneNode(true)
      button.parentNode.replaceChild(newButton, button)
      // Add click handler
      newButton.addEventListener('click', (e) => {
        e.preventDefault()
        e.stopPropagation()
        this.close(e)
      })
    })
    
    // Re-initialize transaction type UI if needed
    if (this.typeValue === "transaction") {
      // Update targets for type radio and cards
      this.typeRadioTargets = Array.from(clonedElement.querySelectorAll('[data-modal-target="typeRadio"]'))
      this.typeCardTargets = Array.from(clonedElement.querySelectorAll('[data-modal-target="typeCard"]'))
      this.descriptionLabelTarget = clonedElement.querySelector('[data-modal-target="descriptionLabel"]')
      this.amountLabelTarget = clonedElement.querySelector('[data-modal-target="amountLabel"]')
      this.dateLabelTarget = clonedElement.querySelector('[data-modal-target="dateLabel"]')
      this.transactionDescriptionTarget = clonedElement.querySelector('[data-modal-target="transactionDescription"]')
      
      // Re-attach change listeners
      this.typeRadioTargets.forEach((radio) => {
        radio.addEventListener('change', () => this.updateTransactionTypeUI())
      })
      
      this.updateTransactionTypeUI()
    }
  }

  // Close the drawer
  close(event) {
    event?.preventDefault()
    
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
    
    // Reset form if present (use original form target)
    if (this.hasFormTarget) {
      setTimeout(() => {
        this.formTarget.reset()
        if (this.typeValue === "transaction") {
          this.updateTransactionTypeUI()
        }
      }, 300)
    }
  }
  
  // Close drawer (mobile)
  closeDrawer() {
    if (this.hasDrawerTarget && this.hasContentTarget) {
      this.contentTarget.classList.remove('sm:mr-96')
      this.drawerTarget.classList.remove('translate-x-0')
      this.drawerTarget.classList.add('translate-x-full')
      
      // Wait for animation to complete before hiding
      setTimeout(() => {
        this.modalTarget.classList.add('hidden')
        this.modalTarget.classList.remove('flex')
      }, 500)
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
      }, 500)
    }
  }

  // Close on background click
  closeOnBackground(event) {
    // Close if clicking on the overlay itself, or on the modal container but not on content
    if (this.hasOverlayTarget && event.target === this.overlayTarget) {
      this.close(event)
    } else if (!this.hasOverlayTarget && event.target === this.modalTarget) {
      // Fallback for modals without overlay target (check if click is on modal but not content)
      const content = this.modalTarget.querySelector('[class*="relative z-10"], [class*="z-10"]')
      if (!content || !content.contains(event.target)) {
        this.close(event)
      }
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
    
    // First, reset all cards to unselected state
    this.typeCardTargets.forEach((card) => {
      card.classList.remove(
        'border-expense-500', 'dark:border-expense-500', 'bg-red-50', 'dark:bg-red-900/20',
        'border-success-500', 'dark:border-success-500', 'bg-green-50', 'dark:bg-green-900/20'
      )
      card.classList.add('border-gray-300', 'dark:border-gray-600', 'bg-white', 'dark:bg-gray-700')
    })
    
    // Find the checked radio and its corresponding card
    // Match by finding the card that's in the same label as the radio button
    this.typeRadioTargets.forEach((radio) => {
      if (radio.checked) {
        selectedType = radio.value
        
        // Find the card that's in the same parent label as this radio
        const label = radio.closest('label')
        if (label) {
          const card = label.querySelector('[data-modal-target="typeCard"]')
          if (card) {
            // Remove unselected classes
            card.classList.remove('border-gray-300', 'dark:border-gray-600', 'bg-white', 'dark:bg-gray-700')
            
            // Add selected classes based on type
            if (radio.value === 'expense') {
              card.classList.add('border-expense-500', 'dark:border-expense-500', 'bg-red-50', 'dark:bg-red-900/20')
            } else {
              card.classList.add('border-success-500', 'dark:border-success-500', 'bg-green-50', 'dark:bg-green-900/20')
            }
          }
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

