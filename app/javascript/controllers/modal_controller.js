import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String }

  connect() {
    // Modal is controlled by Flowbite's modal component
    // This controller handles any additional custom behavior if needed
  }

  open(event) {
    // If event has data-modal-id, use that, otherwise use this element
    const modalId = event?.currentTarget?.dataset?.modalId || this.idValue
    const modal = modalId ? document.getElementById(modalId) : this.element
    
    if (modal) {
      modal.classList.remove('hidden')
      modal.setAttribute('aria-hidden', 'false')
      document.body.style.overflow = 'hidden'
    }
  }

  close(event) {
    // If event has data-modal-id, use that, otherwise use this element
    const modalId = event?.currentTarget?.dataset?.modalId || this.idValue
    const modal = modalId ? document.getElementById(modalId) : this.element
    
    if (modal) {
      modal.classList.add('hidden')
      modal.setAttribute('aria-hidden', 'true')
      document.body.style.overflow = ''
    }
  }

  closeBackground(event) {
    // Only close if clicking the background overlay, not the modal content
    if (event.target === this.element || event.target.classList.contains('bg-gray-500')) {
      this.close(event)
    }
  }
}

