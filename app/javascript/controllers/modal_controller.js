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
    // Cross-controller access: form drawer is shared layout element
    this.formDrawerElement = document.querySelector('[data-controller*="form-drawer"]')
    this.formDrawerController = this.formDrawerElement ? this.application.getControllerForElementAndIdentifier(this.formDrawerElement, 'form-drawer') : null
    
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
    
    // Re-check form drawer controller (it might not be initialized yet)
    if (!this.formDrawerController) {
      this.formDrawerElement = document.querySelector('[data-controller*="form-drawer"]')
      this.formDrawerController = this.formDrawerElement ? this.application.getControllerForElementAndIdentifier(this.formDrawerElement, 'form-drawer') : null
    }
    
    if (isDesktop && this.formDrawerController && this.hasDrawerTarget) {
      // Desktop: Use form drawer
      this.openInDrawer()
    } else {
      // Mobile: Use drawer behavior
      this.openAsDrawer()
    }
    
    if (this.typeValue === "transaction") {
      this.updateTransactionTypeUI()
    }
  }
  
  // Open form in drawer (desktop)
  openInDrawer() {
    // Ensure mobile drawer is reset to initial state (hidden, translated out)
    if (this.hasDrawerTarget) {
      this.drawerTarget.classList.remove('translate-x-0')
      this.drawerTarget.classList.add('translate-x-full')
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove('sm:mr-96')
    }
    
    // Clone drawer content for form drawer
    if (this.hasDrawerTarget && this.formDrawerController) {
      // Clone the drawer content
      const drawerContent = this.drawerTarget.cloneNode(true)
      
      // Remove overlay if present (we don't need it in form drawer)
      const overlay = drawerContent.querySelector('[data-modal-target="overlay"]')
      if (overlay) {
        overlay.remove()
      }
      
      // Remove fixed positioning classes and make it fit drawer
      drawerContent.classList.remove('fixed', 'inset-y-0', 'right-0', 'w-full', 'sm:w-96', 'translate-x-full', 'translate-x-0', 'border-l-2', 'md:top-16', 'md:bottom-0', 'z-50')
      drawerContent.classList.add('w-full', 'h-full', 'flex', 'flex-col')
      
      // Set content in form drawer and open it
      this.formDrawerController.setContentElement(drawerContent)
      this.formDrawerController.open()
      
      // Re-initialize form targets in the new location
      const formDrawerContent = this.formDrawerController.contentTarget
      if (formDrawerContent) {
        this.reinitializeFormTargets(formDrawerContent)
      }
    }
    
    // Keep modal hidden on desktop (form is in drawer, not in modal)
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
    
    if (isDesktop && this.formDrawerController) {
      // Desktop: Close form drawer
      this.closeFromDrawer()
    } else {
      // Mobile: Close drawer
      this.closeDrawer()
    }
  }
  
  // Close from drawer (desktop)
  closeFromDrawer() {
    // Close form drawer
    if (this.formDrawerController) {
      this.formDrawerController.close()
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
        'amount-negative-border', 'amount-negative-bg',
        'amount-positive-border', 'amount-positive-bg'
      )
      card.classList.add('border-neutral-300', 'dark:border-neutral-600', 'bg-white', 'dark:bg-neutral-800')
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
            card.classList.remove('border-neutral-300', 'dark:border-neutral-600', 'bg-white', 'dark:bg-neutral-800')
            
            // Add selected classes based on type
            if (radio.value === 'expense') {
              card.classList.add('amount-negative-border', 'amount-negative-bg')
            } else {
              card.classList.add('amount-positive-border', 'amount-positive-bg')
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

