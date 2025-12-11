import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "modalTitle"]

  connect() {
    console.log('[PlannedTransactionController] Connected', this.element.id)
    
    // Close modal on Escape key
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.boundHandleEscape)
    
    // Listen for custom event dispatched by Turbo Stream
    this.boundHandleModalClosed = this.handleModalClosed.bind(this)
    document.addEventListener('planned-transaction-modal-closed', this.boundHandleModalClosed)
    
    // Set up MutationObserver to watch for form frame removal
    this.setupFormFrameObserver()
  }

  disconnect() {
    console.log('[PlannedTransactionController] Disconnected')
    document.removeEventListener("keydown", this.boundHandleEscape)
    document.removeEventListener('planned-transaction-modal-closed', this.boundHandleModalClosed)
    
    if (this.formFrameObserver) {
      this.formFrameObserver.disconnect()
      this.formFrameObserver = null
    }
  }

  setupFormFrameObserver() {
    const formFrame = document.getElementById("planned-transaction-form")
    if (!formFrame) {
      console.log('[PlannedTransactionController] Form frame not found, will retry on open')
      return
    }
    
    // Disconnect existing observer if any
    if (this.formFrameObserver) {
      this.formFrameObserver.disconnect()
    }
    
    console.log('[PlannedTransactionController] Setting up MutationObserver for form frame')
    
    this.formFrameObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'childList') {
          const formFrame = document.getElementById("planned-transaction-form")
          if (formFrame) {
            const hasForm = !!formFrame.querySelector("form")
            if (!hasForm && formFrame.children.length > 0) {
              // Form was removed but frame still has content (loading state or empty)
              console.log('[PlannedTransactionController] Form removed detected via MutationObserver')
              setTimeout(() => {
                this.close()
              }, 150)
            }
          } else {
            // Frame itself was removed
            console.log('[PlannedTransactionController] Form frame removed detected via MutationObserver')
            setTimeout(() => {
              this.close()
            }, 150)
          }
        }
      })
    })
    
    this.formFrameObserver.observe(formFrame, {
      childList: true,
      subtree: true
    })
  }

  open(event) {
    console.log('[PlannedTransactionController] Opening modal', event)
    event.preventDefault()
    const url = event.params?.url || event.currentTarget.href
    if (!url) {
      console.log('[PlannedTransactionController] No URL provided')
      return
    }

    const formFrame = document.getElementById("planned-transaction-form")
    if (formFrame) {
      console.log('[PlannedTransactionController] Setting form frame src to:', url)
      formFrame.src = url
      // Set up observer when form frame is loaded
      setTimeout(() => {
        this.setupFormFrameObserver()
      }, 200)
    } else {
      console.log('[PlannedTransactionController] Form frame not found')
    }

    if (this.hasModalTarget) {
      this.modalTarget.classList.remove("hidden")
      this.modalTarget.setAttribute("aria-hidden", "false")
      document.body.classList.add("overflow-hidden")
      console.log('[PlannedTransactionController] Modal opened')
    } else {
      console.log('[PlannedTransactionController] Modal target not found')
    }
  }

  close() {
    console.log('[PlannedTransactionController] Closing modal')
    if (this.hasModalTarget) {
      this.modalTarget.classList.add("hidden")
      this.modalTarget.setAttribute("aria-hidden", "true")
      document.body.classList.remove("overflow-hidden")
      
      // Clear form frame
      const formFrame = document.getElementById("planned-transaction-form")
      if (formFrame) {
        formFrame.src = null
        formFrame.innerHTML = '<div class="text-center py-8"><div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div><p class="mt-4 text-gray-600 dark:text-gray-400">Loading form...</p></div>'
      }
      console.log('[PlannedTransactionController] Modal closed')
    } else {
      console.log('[PlannedTransactionController] Modal target not found, cannot close')
    }
  }

  // Handle Turbo Frame form submission success
  formSubmitted(event) {
    console.log('[PlannedTransactionController] formSubmitted event fired', event)
    const formFrame = document.getElementById("planned-transaction-form")
    console.log('[PlannedTransactionController] Form frame exists:', !!formFrame)
    console.log('[PlannedTransactionController] Form frame has form:', formFrame ? !!formFrame.querySelector("form") : false)
    
    if (formFrame && !formFrame.querySelector("form")) {
      console.log('[PlannedTransactionController] Form was removed, closing modal')
      // Form was removed (successful submission)
      setTimeout(() => {
        this.close()
      }, 150) // Small delay to allow Turbo Stream broadcasts to complete
    } else {
      console.log('[PlannedTransactionController] Form still exists, will wait for removal')
      // Set up a check to watch for form removal
      let checkCount = 0
      const maxChecks = 50 // 5 seconds max
      const checkInterval = setInterval(() => {
        checkCount++
        const formFrame = document.getElementById("planned-transaction-form")
        if (!formFrame || !formFrame.querySelector("form")) {
          console.log('[PlannedTransactionController] Form removed detected via polling (check #' + checkCount + ')')
          clearInterval(checkInterval)
          this.close()
        } else if (checkCount >= maxChecks) {
          console.log('[PlannedTransactionController] Stopped polling for form removal after ' + maxChecks + ' checks')
          clearInterval(checkInterval)
        }
      }, 100)
    }
  }

  handleModalClosed() {
    console.log('[PlannedTransactionController] handleModalClosed event received')
    // Fallback: ensure modal is closed when event is dispatched
    if (this.hasModalTarget && !this.modalTarget.classList.contains('hidden')) {
      console.log('[PlannedTransactionController] Closing modal via handleModalClosed')
      this.close()
    } else {
      console.log('[PlannedTransactionController] Modal already closed or target not found')
    }
  }

  handleEscape(event) {
    if (event.key === "Escape" && this.hasModalTarget && !this.modalTarget.classList.contains("hidden")) {
      console.log('[PlannedTransactionController] Escape key pressed, closing modal')
      this.close()
    }
  }
}
