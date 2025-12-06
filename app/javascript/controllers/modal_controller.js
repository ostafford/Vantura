import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Modal is controlled by Flowbite's modal component
    // This controller handles any additional custom behavior if needed
  }

  open() {
    this.element.classList.remove('hidden')
    this.element.setAttribute('aria-hidden', 'false')
    document.body.style.overflow = 'hidden'
  }

  close() {
    this.element.classList.add('hidden')
    this.element.setAttribute('aria-hidden', 'true')
    document.body.style.overflow = ''
  }
}

